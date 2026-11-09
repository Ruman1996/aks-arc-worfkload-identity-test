export LOCATION="eastus"
export RESOURCE_GROUP="kml_rg_main-951bd60c4be54f3c"
export AKS_NAME="test-gh-runner"

export AKS_NAMESPACE_CONTROLLER="arc-systems"
export AKS_NAMESPACE_RUNNERS="arc-runners"

export IDENTITY_NAME="uami-gh-token-broker"
export SERVICE_ACCOUNT="gha-kv-reader"

export KEYVAULT_NAME="kv-arc-platform-test"
export SECRET_NAME="arc-poc-secret"

export GITHUB_CONFIG_URL="https://github.com/user-gihub-account"
export RUNNER_SET_NAME="arc-kv-poc"


# command to check the current AKS config 
az aks show \
  --resource-group kml_rg_main-951bd60c4be54f3c \
  --name test-gh-runner \
  --query '{
    oidcIssuer:oidcIssuerProfile.issuerUrl,
    oidcEnabled:oidcIssuerProfile.enabled,
    workloadIdentity:securityProfile.workloadIdentity.enabled
  }' \
  -o yaml

output:
oidcEnabled: true
oidcIssuer: https://eastus.oic.prod-aks.azure.com/30fe8ff1-adc6-444d-ba94-1238894df42c/61e73d48-c17f-42fb-8c81-1fe455395f5f/
workloadIdentity: true


# command:
az account set --subscription a2b28c85-1948-4263-90ca-bade2bac4df4
az aks get-credentials --resource-group kml_rg_main-951bd60c4be54f3c --name test-gh-runner --overwrite-existing

kubectl create namespace arc-systems
kubectl create namespace arc-runners
kubectl create namespace platform-security


az identity create \
  --resource-group kml_rg_main-951bd60c4be54f3c \
  --name uami-gh-token-broker \
  --location eastus
  
output:
{
  "assignmentRestrictions": {
    "providers": []
  },
  "clientId": "888dd375-e5eb-4440-b378-b42f7c566e37",
  "id": "/subscriptions/a2b28c85-1948-4263-90ca-bade2bac4df4/resourcegroups/kml_rg_main-951bd60c4be54f3c/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-gh-token-broker",
  "isolationScope": "None",
  "location": "eastus",
  "name": "uami-gh-token-broker",
  "principalId": "7ebeef57-6c6b-4b59-8cd2-331c3753e30c",
  "resourceGroup": "kml_rg_main-951bd60c4be54f3c",
  "tags": {},
  "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}


command:

az keyvault create \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku standard \
  --enable-rbac-authorization true \
  --retention-days 7

# enable-purge-protection cannot be set to false, only true can be set KK had a limitation, for both this and retentation-days + sku 

output: 
{
  "id": "/subscriptions/a2b28c85-1948-4263-90ca-bade2bac4df4/resourceGroups/kml_rg_main-951bd60c4be54f3c/providers/Microsoft.KeyVault/vaults/kv-arc-platform-test",
  "location": "eastus",
  "name": "kv-arc-platform-test",
  "properties": {
    "accessPolicies": [],
    "createMode": null,
    "enablePurgeProtection": null,
    "enableRbacAuthorization": true,
    "enableSoftDelete": true,
    "enabledForDeployment": false,
    "enabledForDiskEncryption": false,
    "enabledForTemplateDeployment": false,
    "hsmPoolResourceId": null,
    "networkAcls": null,
    "privateEndpointConnections": null,
    "provisioningState": "Succeeded",
    "publicNetworkAccess": "Enabled",
    "sku": {
      "family": "A",
      "name": "standard"
    },
    "softDeleteRetentionInDays": 7,
    "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c",
    "vaultUri": "https://kv-arc-platform-test.vault.azure.net/"
  },
  "resourceGroup": "kml_rg_main-951bd60c4be54f3c",
  "systemData": {
    "createdAt": "2026-11-09T11:48:58.914000+00:00",
    "createdBy": "kk_lab_user_main-951bd60c4be54f3c@azurekmlprodkodekloud.onmicrosoft.com",
    "createdByType": "User",
    "lastModifiedAt": "2026-11-09T11:48:58.914000+00:00",
    "lastModifiedBy": "kk_lab_user_main-951bd60c4be54f3c@azurekmlprodkodekloud.onmicrosoft.com",
    "lastModifiedByType": "User"
  },
  "tags": {},
  "type": "Microsoft.KeyVault/vaults"
}


command:
export KEYVAULT_URL=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.vaultUri \
  -o tsv)

export KEYVAULT_ID=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  -o tsv)

echo "$KEYVAULT_URL"

output:
https://kv-arc-platform-test.vault.azure.net/

# assigning permission to self account to get the access 
export MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --assignee-object-id "$MY_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Key Vault Secrets Officer" \
  --scope "$KEYVAULT_ID"

# above command failed - not sure, why the creator of the key vault would ask for a request? 

az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "$SECRET_NAME" \
  --value "Hello-from-Azure-Key-Vault"

#UMAI creation
az identity create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$IDENTITY_NAME" \
  --location "$LOCATION"

output:
{
  "assignmentRestrictions": {
    "providers": []
  },
  "clientId": "888dd375-e5eb-4440-b378-b42f7c566e37",
  "id": "/subscriptions/a2b28c85-1948-4263-90ca-bade2bac4df4/resourcegroups/kml_rg_main-951bd60c4be54f3c/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-gh-token-broker",
  "isolationScope": "None",
  "location": "eastus",
  "name": "uami-gh-token-broker",
  "principalId": "7ebeef57-6c6b-4b59-8cd2-331c3753e30c",
  "resourceGroup": "kml_rg_main-951bd60c4be54f3c",
  "tags": {},
  "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}

command:
export UAMI_CLIENT_ID=$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$IDENTITY_NAME" \
  --query clientId -o tsv)

export UAMI_PRINCIPAL_ID=$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$IDENTITY_NAME" \
  --query principalId -o tsv)

export TENANT_ID=$(az account show --query tenantId -o tsv)

command:
echo "Client ID: $UAMI_CLIENT_ID"
echo "Principal ID: $UAMI_PRINCIPAL_ID"
echo "Tenant ID: $TENANT_ID"

output:
Client ID: 888dd375-e5eb-4440-b378-b42f7c566e37
Principal ID: 7ebeef57-6c6b-4b59-8cd2-331c3753e30c
Tenant ID: 30fe8ff1-adc6-444d-ba94-1238894df42c


# checking permissios: 

export EXISTING_KV_ID=$(az keyvault show \
  --name "kv-arc-platform-test" \
  --resource-group "kml_rg_main-951bd60c4be54f3c" \
  --query id -o tsv)
az role assignment list \
  --scope "$EXISTING_KV_ID" \
  --include-inherited \
  --all \
  --query "[].{
    role:roleDefinitionName,
    scope:scope,
    principal:principalName
  }" \
  -o table

# using access policy route instead of RBAC 

az keyvault create   --name "$KV_NAME"   --resource-group "$RESOURCE_GROUP"   --location "$LOCATION"   --enable-rbac-authorization false  --sku standard --retention-days 7 


az keyvault set-policy \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --object-id "7ebeef57-6c6b-4b59-8cd2-331c3753e30c" \
  --secret-permissions get


output: 
z keyvault set-policy \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --object-id "7ebeef57-6c6b-4b59-8cd2-331c3753e30c" \
  --secret-permissions get
{
  "id": "/subscriptions/a2b28c85-1948-4263-90ca-bade2bac4df4/resourceGroups/kml_rg_main-951bd60c4be54f3c/providers/Microsoft.KeyVault/vaults/kv-access-policy",
  "location": "eastus",
  "name": "kv-access-policy",
  "properties": {
    "accessPolicies": [
      {
        "applicationId": null,
        "objectId": "af92d19f-fb14-402f-be65-924a2581431e",
        "permissions": {
          "certificates": [
            "all"
          ],
          "keys": [
            "all"
          ],
          "secrets": [
            "all"
          ],
          "storage": [
            "all"
          ]
        },
        "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c"
      },
      {
        "applicationId": null,
        "objectId": "7ebeef57-6c6b-4b59-8cd2-331c3753e30c",
        "permissions": {
          "certificates": null,
          "keys": null,
          "secrets": [
            "get"
          ],
          "storage": null
        },
        "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c"
      }
    ],
    "createMode": null,
    "enablePurgeProtection": null,
    "enableRbacAuthorization": false,
    "enableSoftDelete": true,
    "enabledForDeployment": false,
    "enabledForDiskEncryption": false,
    "enabledForTemplateDeployment": false,
    "hsmPoolResourceId": null,
    "networkAcls": null,
    "privateEndpointConnections": null,
    "provisioningState": "Succeeded",
    "publicNetworkAccess": "Enabled",
    "sku": {
      "family": "A",
      "name": "standard"
    },
    "softDeleteRetentionInDays": 7,
    "tenantId": "30fe8ff1-adc6-444d-ba94-1238894df42c",
    "vaultUri": "https://kv-access-policy.vault.azure.net/"
  },
  "resourceGroup": "kml_rg_main-951bd60c4be54f3c",
  "systemData": {
    "createdAt": "2026-11-09T12:18:34.101000+00:00",
    "createdBy": "kk_lab_user_main-951bd60c4be54f3c@azurekmlprodkodekloud.onmicrosoft.com",
    "createdByType": "User",
    "lastModifiedAt": "2026-11-09T12:23:19.320000+00:00",
    "lastModifiedBy": "kk_lab_user_main-951bd60c4be54f3c@azurekmlprodkodekloud.onmicrosoft.com",
    "lastModifiedByType": "User"
  },
  "tags": {},
  "type": "Microsoft.KeyVault/vaults"
}


# secret creation on new KV : 
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "arc-poc-secret" \
  --value "Hello-from-ARC-Workload-Identity"
{
  "attributes": {
    "created": "2026-11-09T12:24:34+00:00",
    "enabled": true,
    "expires": null,
    "notBefore": null,
    "recoverableDays": 7,
    "recoveryLevel": "CustomizedRecoverable+Purgeable",
    "updated": "2026-11-09T12:24:34+00:00"
  },
  "contentType": null,
  "id": "https://kv-access-policy.vault.azure.net/secrets/arc-poc-secret/3660b08eddb64d2cbcdeebf73b184246",
  "kid": null,
  "managed": null,
  "name": "arc-poc-secret",
  "tags": {
    "file-encoding": "utf-8"
  },
  "value": "Hello-from-ARC-Workload-Identity"
}


# giving access to the trust in the UMAI 

export AKS_ISSUER=$(az aks show \
  -g "$RESOURCE_GROUP" \
  -n "$AKS_NAME" \
  --query oidcIssuerProfile.issuerUrl -o tsv)
  
az identity federated-credential create \
  --name fic-gha-kv-reader \
  --resource-group "kml_rg_main-951bd60c4be54f3c" \
  --identity-name "uami-gh-token-broker" \
  --issuer "$AKS_ISSUER" \
  --subject "system:serviceaccount:arc-runners:gha-kv-reader" \
  --audiences "api://AzureADTokenExchange"


az identity federated-credential create \
  --name fic-gha-kv-reader \
  --resource-group "kml_rg_main-951bd60c4be54f3c" \
  --identity-name "uami-gh-token-broker" \
  --issuer "$AKS_ISSUER" \
  --subject "system:serviceaccount:arc-runners:gha-kv-reader" \
  --audiences "api://AzureADTokenExchange"
{
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "id": "/subscriptions/a2b28c85-1948-4263-90ca-bade2bac4df4/resourcegroups/kml_rg_main-951bd60c4be54f3c/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-gh-token-broker/federatedIdentityCredentials/fic-gha-kv-reader",
  "issuer": "https://eastus.oic.prod-aks.azure.com/30fe8ff1-adc6-444d-ba94-1238894df42c/61e73d48-c17f-42fb-8c81-1fe455395f5f/",
  "name": "fic-gha-kv-reader",
  "resourceGroup": "kml_rg_main-951bd60c4be54f3c",
  "subject": "system:serviceaccount:arc-runners:gha-kv-reader",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials"
}


# github app secret creation
export GITHUB_APP_ID="5679935"
export GITHUB_APP_INSTALLATION_ID="180143290"
export GITHUB_APP_PRIVATE_KEY_FILE="./key.pem"

kubectl create secret generic arc-github-app \
  --namespace arc-runners \
  --from-literal=github_app_id="$GITHUB_APP_ID" \
  --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
  --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE"

# arc installtion charts - check the version present 

helm show chart \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

helm show chart \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

output: 

helm show chart \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller:0.15.1
Digest: sha256:c2497a6dedaaa723322abfe9ea2f5a81b9b8fbb90b38e45d7835b6c7629a3aae
apiVersion: v2
appVersion: 0.15.1
description: A Helm chart for install actions-runner-controller CRD
home: https://github.com/actions/actions-runner-controller
maintainers:
- name: actions
  url: https://github.com/actions
name: gha-runner-scale-set-controller
sources:
- https://github.com/actions/actions-runner-controller
type: application
version: 0.15.1

Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set:0.15.1
Digest: sha256:2ae7e43db61047aa3c4182e73c8f58ace35e796fa07d41b64fb3c39e81e1f365
apiVersion: v2
appVersion: 0.15.1
description: A Helm chart for deploying an AutoScalingRunnerSet
home: https://github.com/actions/actions-runner-controller
maintainers:
- name: actions
  url: https://github.com/actions
name: gha-runner-scale-set
sources:
- https://github.com/actions/actions-runner-controller
type: application
version: 0.15.1





export ARC_VERSION="0.15.1"

helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-systems \
  --create-namespace \
  --version "$ARC_VERSION"

output: 
Release "arc" does not exist. Installing it now.
Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller:0.15.1
Digest: sha256:c2497a6dedaaa723322abfe9ea2f5a81b9b8fbb90b38e45d7835b6c7629a3aae
NAME: arc
LAST DEPLOYED: Mon Nov  9 12:44:24 2026
NAMESPACE: arc-systems
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
Thank you for installing gha-runner-scale-set-controller.

Your release is named arc.

# check pod running for the controller 

helm list -n arc-systems

kubectl get pods -n arc-systems -w
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                                   APP VERSION
arc     arc-systems     1               2026-11-09 12:44:24.238262223 +0000 UTC deployed        gha-runner-scale-set-controller-0.15.1  0.15.1     
NAME                                    READY   STATUS    RESTARTS   AGE
arc-gha-rs-controller-d6d787688-6xpz6   1/1     Running   0          71s

7. Configure the ARC runner scale set with the UAMI
This is the most important configuration in this PoC.

We will configure the runner pod template with:
- serviceAccountName: gha-kv-reader
- azure.workload.identity/use: "true"
That is how the runner receives the Azure identity


export GITHUB_CONFIG_URL="https://github.com/user-gihub-account"



helm template arc-kv-poc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners \
  --version "$ARC_VERSION" \
  -f arc-runner-values.yaml
