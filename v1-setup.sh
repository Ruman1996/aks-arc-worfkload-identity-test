#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 1. CONFIGURATION
# ============================================================

export SUBSCRIPTION_ID="a2b28c85-1948-4263-90ca-bade2bac4df4"

export LOCATION="eastus"
export RESOURCE_GROUP="kml_rg_main-c00c35e5539841e7"
export AKS_NAME="test-gh-runner"

# ARC namespaces
export ARC_CONTROLLER_NAMESPACE="arc-systems"
export ARC_RUNNER_NAMESPACE="arc-runners"

# User Assigned Managed Identity
# V1 uses this identity directly for Key Vault access.
export UAMI_NAME="uami-gh-kv-reader"

# Key Vault - Access Policy authorization mode
# The existing kv-access-policy vault in your notes used this mode.
export KEYVAULT_NAME="kv-access-policy-1"
export SECRET_NAME="arc-poc-secret"
export SECRET_VALUE="Hello-from-ARC-Workload-Identity"

# Kubernetes ServiceAccount
export SERVICE_ACCOUNT_NAME="gha-kv-reader"

# Federated credential
export FEDERATED_CREDENTIAL_NAME="fic-gha-kv-reader"

# Existing GitHub App - no App creation is performed here.
export GITHUB_OWNER="ruman1996"
export GITHUB_REPOSITORY="aks-arc-worfkload-identity-test"
export GITHUB_CONFIG_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"

export GITHUB_APP_ID="5679935"
export GITHUB_APP_INSTALLATION_ID="180143290"
export GITHUB_APP_PRIVATE_KEY_FILE="./key.pem"
export GITHUB_APP_SECRET_NAME="arc-github-app"

# ARC chart version
export ARC_VERSION="0.15.1"

# ARC scale set
export RUNNER_SET_NAME="arc-kv-poc"
export RUNNER_VALUES_FILE="./runner-values.yaml"

# ============================================================
# 2. PREREQUISITE VALIDATION
# ============================================================

echo "===== Checking prerequisites ====="

for cmd in az kubectl helm; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $cmd"
    exit 1
  }
done

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_FILE" ]]; then
  echo "ERROR: GitHub App private key not found: $GITHUB_APP_PRIVATE_KEY_FILE"
  exit 1
fi

if [[ "$GITHUB_OWNER" == "your-github-owner" ||
      "$GITHUB_REPOSITORY" == "your-repository" ]]; then
  echo "ERROR: Set GITHUB_OWNER and GITHUB_REPOSITORY before running."
  exit 1
fi

if [[ ! "$GITHUB_CONFIG_URL" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
  echo "ERROR: GITHUB_CONFIG_URL must point to a repository."
  exit 1
fi

echo "Prerequisites validated."

# ============================================================
# 3. AZURE SUBSCRIPTION
# ============================================================

echo "===== Selecting Azure subscription ====="

az account set --subscription "$SUBSCRIPTION_ID"

az account show \
  --query '{subscription:name,subscriptionId:id,tenantId:tenantId}' \
  -o yaml

TENANT_ID=$(az account show --query tenantId -o tsv)

# ============================================================
# 4. VERIFY EXISTING AKS CLUSTER
# ============================================================

echo "===== Verifying existing AKS cluster ====="

AKS_CONFIG=$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --query '{
    oidcEnabled:oidcIssuerProfile.enabled,
    oidcIssuer:oidcIssuerProfile.issuerUrl,
    workloadIdentity:securityProfile.workloadIdentity.enabled
  }' \
  -o json)

echo "$AKS_CONFIG"

OIDC_ENABLED=$(echo "$AKS_CONFIG" | jq -r '.oidcEnabled')
WORKLOAD_IDENTITY_ENABLED=$(echo "$AKS_CONFIG" | jq -r '.workloadIdentity')
AKS_ISSUER=$(echo "$AKS_CONFIG" | jq -r '.oidcIssuer')

if [[ "$OIDC_ENABLED" != "true" ||
      "$WORKLOAD_IDENTITY_ENABLED" != "true" ||
      -z "$AKS_ISSUER" ||
      "$AKS_ISSUER" == "null" ]]; then
  echo "ERROR: AKS must have OIDC issuer and Workload Identity enabled."
  exit 1
fi

echo "AKS OIDC issuer: $AKS_ISSUER"

# ============================================================
# 5. CONNECT TO AKS AND CREATE NAMESPACES
# ============================================================

echo "===== Connecting to AKS ====="

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing

kubectl get nodes

echo "===== Creating ARC namespaces ====="

kubectl create namespace "$ARC_CONTROLLER_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace "$ARC_RUNNER_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# ============================================================
# 6. CREATE OR REUSE USER ASSIGNED MANAGED IDENTITY
# ============================================================

echo "===== Creating or reusing UAMI ====="

if az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$UAMI_NAME" >/dev/null 2>&1; then

  echo "UAMI already exists. Reusing it."

else

  az identity create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$UAMI_NAME" \
    --location "$LOCATION"

fi

UAMI_CLIENT_ID=$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$UAMI_NAME" \
  --query clientId -o tsv)

UAMI_PRINCIPAL_ID=$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$UAMI_NAME" \
  --query principalId -o tsv)

echo "UAMI client ID: $UAMI_CLIENT_ID"
echo "UAMI principal ID: $UAMI_PRINCIPAL_ID"

# ============================================================
# 7. CREATE KEY VAULT IN ACCESS POLICY MODE
# ============================================================

echo "===== Creating or validating Key Vault ====="

if az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then

  echo "Key Vault already exists. Checking authorization mode."

else

  az keyvault create \
    --name "$KEYVAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku standard \
    --enable-rbac-authorization false \
    --retention-days 7

fi

KV_RBAC_MODE=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.enableRbacAuthorization \
  -o tsv)

if [[ "$KV_RBAC_MODE" != "false" ]]; then
  echo "ERROR: Key Vault is using RBAC authorization."
  echo "This V1 script requires Access Policy authorization."
  echo "Use a new vault or explicitly migrate the existing vault before rerunning."
  exit 1
fi

KEYVAULT_URL=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.vaultUri -o tsv)

echo "Key Vault URL: $KEYVAULT_URL"
echo "Key Vault authorization: Access Policy"

# ============================================================
# 8. GRANT CURRENT AZURE USER PERMISSION TO CREATE TEST SECRET
# ============================================================

echo "===== Configuring administrator access policy ====="

# MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# az keyvault set-policy \
#   --name "$KEYVAULT_NAME" \
#   --resource-group "$RESOURCE_GROUP" \
#   --object-id "$MY_OBJECT_ID" \
#   --secret-permissions get list set

# ============================================================
# 9. CREATE TEST SECRET
# ============================================================

echo "===== Creating test secret ====="

az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "$SECRET_NAME" \
  --value "$SECRET_VALUE" \
  --output none

echo "Test secret created."

# ============================================================
# 10. GRANT UAMI ONLY SECRET GET PERMISSION
# ============================================================

echo "===== Granting UAMI Key Vault permission ====="

az keyvault set-policy \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --object-id "$UAMI_PRINCIPAL_ID" \
  --secret-permissions get

echo "UAMI granted secrets/get permission."

# ============================================================
# 11. CREATE FEDERATED IDENTITY CREDENTIAL
# ============================================================

echo "===== Creating federated identity credential ====="

if az identity federated-credential show \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$UAMI_NAME" \
  --name "$FEDERATED_CREDENTIAL_NAME" >/dev/null 2>&1; then

  echo "Federated credential already exists. Updating it."

fi

az identity federated-credential create \
  --name "$FEDERATED_CREDENTIAL_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$UAMI_NAME" \
  --issuer "$AKS_ISSUER" \
  --subject "system:serviceaccount:${ARC_RUNNER_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" \
  --audiences "api://AzureADTokenExchange"

# ============================================================
# 12. CREATE KUBERNETES SERVICE ACCOUNT
# ============================================================

echo "===== Creating runner ServiceAccount ====="

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${ARC_RUNNER_NAMESPACE}
  annotations:
    azure.workload.identity/client-id: "${UAMI_CLIENT_ID}"
EOF

kubectl get serviceaccount \
  "$SERVICE_ACCOUNT_NAME" \
  -n "$ARC_RUNNER_NAMESPACE" \
  -o yaml

# ============================================================
# 13. CREATE GITHUB APP KUBERNETES SECRET
# ============================================================

echo "===== Creating GitHub App secret ====="

kubectl create secret generic "$GITHUB_APP_SECRET_NAME" \
  --namespace "$ARC_RUNNER_NAMESPACE" \
  --from-literal=github_app_id="$GITHUB_APP_ID" \
  --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
  --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "GitHub App secret created."

# ============================================================
# 14. INSTALL ARC CONTROLLER
# ============================================================

echo "===== Installing ARC controller ====="

helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace "$ARC_CONTROLLER_NAMESPACE" \
  --create-namespace \
  --version "$ARC_VERSION" \
  --wait \
  --timeout 5m

echo "===== Waiting for ARC controller ====="

CONTROLLER_DEPLOYMENT=$(kubectl get deployments \
  -n "$ARC_CONTROLLER_NAMESPACE" \
  -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$CONTROLLER_DEPLOYMENT" ]]; then
  echo "ERROR: ARC controller deployment not found."
  exit 1
fi

kubectl rollout status \
  "deployment/${CONTROLLER_DEPLOYMENT}" \
  -n "$ARC_CONTROLLER_NAMESPACE" \
  --timeout=300s

CONTROLLER_SERVICE_ACCOUNT=$(kubectl get deployment \
  "$CONTROLLER_DEPLOYMENT" \
  -n "$ARC_CONTROLLER_NAMESPACE" \
  -o jsonpath='{.spec.template.spec.serviceAccountName}')

if [[ -z "$CONTROLLER_SERVICE_ACCOUNT" ]]; then
  echo "ERROR: Could not determine ARC controller ServiceAccount."
  exit 1
fi

echo "Controller deployment: $CONTROLLER_DEPLOYMENT"
echo "Controller ServiceAccount: $CONTROLLER_SERVICE_ACCOUNT"

# ============================================================
# 15. GENERATE RUNNER SCALE SET VALUES
# ============================================================

echo "===== Generating runner scale set values ====="

cat > "$RUNNER_VALUES_FILE" <<EOF
githubConfigUrl: "${GITHUB_CONFIG_URL}"
githubConfigSecret: "${GITHUB_APP_SECRET_NAME}"

runnerScaleSetName: "${RUNNER_SET_NAME}"

minRunners: 0
maxRunners: 1

controllerServiceAccount:
  namespace: "${ARC_CONTROLLER_NAMESPACE}"
  name: "${CONTROLLER_SERVICE_ACCOUNT}"

template:
  metadata:
    labels:
      azure.workload.identity/use: "true"
  spec:
    serviceAccountName: "${SERVICE_ACCOUNT_NAME}"
EOF

echo "Generated $RUNNER_VALUES_FILE"

# ============================================================
# 16. INSTALL ARC RUNNER SCALE SET
# ============================================================

echo "===== Installing ARC runner scale set ====="

helm upgrade --install "$RUNNER_SET_NAME" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "$ARC_RUNNER_NAMESPACE" \
  --version "$ARC_VERSION" \
  --values "$RUNNER_VALUES_FILE" \
  --wait \
  --timeout 5m

# ============================================================
# 17. VALIDATE INSTALLATION
# ============================================================

echo "===== ARC controller status ====="

kubectl get pods -n "$ARC_CONTROLLER_NAMESPACE"

echo "===== ARC runner namespace ====="

kubectl get pods -n "$ARC_RUNNER_NAMESPACE"

echo "===== ARC Helm releases ====="

helm list -n "$ARC_CONTROLLER_NAMESPACE"
helm list -n "$ARC_RUNNER_NAMESPACE"

echo "===== Key Vault authorization mode ====="

az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{
    name:name,
    vaultUri:properties.vaultUri,
    enableRbacAuthorization:properties.enableRbacAuthorization
  }' \
  -o yaml

echo "===== UAMI federated credential ====="

az identity federated-credential show \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$UAMI_NAME" \
  --name "$FEDERATED_CREDENTIAL_NAME" \
  -o yaml

echo "================================================"
echo "AKS ARC KEY VAULT V1 SETUP COMPLETED"
echo "================================================"
echo "Runner scale set: $RUNNER_SET_NAME"
echo "GitHub repository: $GITHUB_CONFIG_URL"
echo "Key Vault URL: $KEYVAULT_URL"
echo "Secret name: $SECRET_NAME"
echo "UAMI client ID: $UAMI_CLIENT_ID"
echo "Runner ServiceAccount: $SERVICE_ACCOUNT_NAME"
echo "================================================"
