# Azure IAM Policies for Storm Surge

This directory contains Azure RBAC (Role-Based Access Control) definitions for managing AKS clusters and associated resources.

## Files

### aks-admin-role.json
Custom Azure role definition that provides comprehensive permissions for AKS administration, including:
- Full AKS cluster management
- Virtual networks and network security
- Virtual machines and scale sets
- Load balancers and application gateways
- Key Vault for secrets management
- Container Registry access
- Monitoring and diagnostics
- Managed identities

## Usage

### Create Custom Role

```bash
# Create custom role at subscription level
az role definition create --role-definition aks-admin-role.json

# Update the role definition if it already exists
az role definition update --role-definition aks-admin-role.json
```

### Create Service Principal with Role

```bash
# Create service principal and assign custom role
az ad sp create-for-rbac \
  --name "storm-surge-aks-admin" \
  --role "Storm Surge AKS Administrator" \
  --scopes /subscriptions/{subscription-id}

# This will output:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "storm-surge-aks-admin",
#   "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }
```

### Assign Role to User

```bash
# Assign custom role to a user
az role assignment create \
  --assignee user@example.com \
  --role "Storm Surge AKS Administrator" \
  --scope /subscriptions/{subscription-id}
```

### Using Built-in Roles (Alternative)

If you prefer using built-in roles instead of custom role:

```bash
# Required built-in roles for full AKS administration
PRINCIPAL_ID=$(az ad sp show --id "storm-surge-aks-admin" --query id -o tsv)

# Contributor role for general resource management
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Contributor" \
  --scope /subscriptions/{subscription-id}

# Network Contributor for networking resources
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Network Contributor" \
  --scope /subscriptions/{subscription-id}

# Key Vault Administrator for secrets management
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Administrator" \
  --scope /subscriptions/{subscription-id}
```

## Authentication

### Using Service Principal

```bash
# Login with service principal
az login --service-principal \
  --username {app-id} \
  --password {password} \
  --tenant {tenant-id}

# Set the subscription context
az account set --subscription {subscription-id}
```

### Using Managed Identity (Recommended for Production)

```bash
# Create user-assigned managed identity
az identity create \
  --name storm-surge-aks-identity \
  --resource-group storm-surge-rg

# Get identity details
IDENTITY_CLIENT_ID=$(az identity show \
  --name storm-surge-aks-identity \
  --resource-group storm-surge-rg \
  --query clientId -o tsv)

IDENTITY_RESOURCE_ID=$(az identity show \
  --name storm-surge-aks-identity \
  --resource-group storm-surge-rg \
  --query id -o tsv)

# Assign role to managed identity
az role assignment create \
  --assignee $IDENTITY_CLIENT_ID \
  --role "Storm Surge AKS Administrator" \
  --scope /subscriptions/{subscription-id}
```

## Using with AKS

### Create AKS Cluster with Service Principal

```bash
# Create resource group
az group create --name storm-surge-rg --location eastus

# Create AKS cluster with service principal
az aks create \
  --resource-group storm-surge-rg \
  --name storm-surge-aks \
  --service-principal {app-id} \
  --client-secret {password} \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys
```

### Create AKS Cluster with Managed Identity

```bash
# Create AKS cluster with managed identity
az aks create \
  --resource-group storm-surge-rg \
  --name storm-surge-aks \
  --enable-managed-identity \
  --assign-identity $IDENTITY_RESOURCE_ID \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys
```

## Security Best Practices

1. **Service Principal Secrets**: Store credentials in Azure Key Vault
2. **Managed Identities**: Use managed identities instead of service principals when possible
3. **Least Privilege**: Review and minimize permissions based on actual needs
4. **Resource Locks**: Apply resource locks to prevent accidental deletion
5. **Azure Policy**: Use Azure Policy for governance and compliance
6. **Activity Logs**: Enable and monitor Azure Activity Logs

## Required Resource Providers

Ensure these resource providers are registered:

```bash
# Register required providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry

# Check registration status
az provider list --query "[?namespace=='Microsoft.ContainerService'].registrationState" -o tsv
```

## Scope Considerations

The custom role can be assigned at different scopes:
- **Management Group**: For managing multiple subscriptions
- **Subscription**: For managing all resources in a subscription
- **Resource Group**: For managing resources in specific resource groups

Update the `AssignableScopes` in the role definition based on your requirements.