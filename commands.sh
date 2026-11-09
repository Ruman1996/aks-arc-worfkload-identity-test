export LOCATION="eastus"
export RESOURCE_GROUP="kml_rg_main-951bd60c4be54f3c"
export AKS_NAME="test-gh-runner"

export AKS_NAMESPACE_CONTROLLER="arc-systems"
export AKS_NAMESPACE_RUNNERS="arc-runners"

export IDENTITY_NAME="uami-gh-token-broker"
export SERVICE_ACCOUNT="gha-kv-reader"

export KEYVAULT_NAME="kv-arc-platform-test"
export SECRET_NAME="arc-poc-secret"

export GITHUB_CONFIG_URL="https://github.com/ruman1996"
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
