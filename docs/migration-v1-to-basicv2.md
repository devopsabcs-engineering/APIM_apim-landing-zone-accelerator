# APIM Migration Guide: Classic v1 to BasicV2

## Overview

This guide documents lessons learned migrating from Azure APIM Classic Developer/Premium SKU (v1, stv2 platform) to the newer BasicV2 SKU.

## SKU Comparison

| Feature | Developer (v1) | BasicV2 |
|---------|----------------|---------|
| Monthly cost | ~$50 | ~$150 |
| SLA | None | 99.95% |
| VNet integration | External/Internal | Not supported |
| Availability zones | Yes (Premium) | No |
| Workspaces | Yes (Premium) | Not supported |
| Workspace gateways | Yes (Premium) | Not supported |
| Max APIs | Unlimited | Unlimited |
| Custom domains | Yes | Yes |
| Developer portal | Yes | Yes |
| OAuth2 authorization servers | Yes | Yes (manual setup) |
| Azure AD identity provider | Built-in | Manual setup |
| Platform version | stv2 | v2 |

## Migration Steps

### 1. Deploy BasicV2 Infrastructure

Use the `deploy-apim-basicv2.yml` workflow or deploy manually:

```bash
az deployment group create \
  --resource-group rg-apim-basicv2-dev-006 \
  --template-file infra/api-management-basicv2/main.bicep \
  --parameters infra/api-management-basicv2/main.parameters.dev-006.json
```

### 2. Prepare Artifacts for BasicV2

When copying artifacts from a v1 instance, remove or update:

#### Named Values

- **Remove Key Vault references** pointing to the old instance's Key Vault
- **Replace with plain values** or update Key Vault URIs to the new instance
- **Remove `instrumentationKey`** named value (managed by Bicep)

#### Groups

- **Remove external AAD groups** (IDs like `66ed0b567e59f1ebb2a9bb75`)
- Keep only `system` groups (administrators, developers, guests) and `custom` groups

#### APIs

- **Remove `authenticationSettings.oAuth2`** references (authorization server not present)
- **Update `serviceUrl`** references from old instance gateway URL to new instance

#### Subscriptions

- **Remove all subscriptions** referencing old instance users/products
- Subscriptions are recreated via developer portal or manually

#### Products

- **Remove product-group associations** for deleted external groups

#### Workspaces

- **Remove workspace artifacts entirely** (not supported on BasicV2)

### 3. Publish to BasicV2

Run the publisher workflow with `publish-all-artifacts-in-repo` to push all cleaned artifacts.

### 4. Post-Migration Setup

After initial publish, manually configure:

1. **OAuth2 Authorization Server** (if needed for API authentication settings)
2. **Azure AD Identity Provider** (if using external AAD groups)
3. **Users** via developer portal sign-up or Azure portal
4. **Subscriptions** for products

## Automation Gaps

These items cannot be managed via APIops publisher and need separate automation:

| Item | Status | Approach |
|------|--------|----------|
| OAuth2 authorization servers | Manual | Azure CLI or Bicep |
| Azure AD identity provider | Manual | Azure CLI |
| Users | Manual | Developer portal |
| Subscriptions with specific users | Manual | Azure CLI |
| External AAD groups | Manual | Azure CLI after identity provider setup |

## Future Work

- Script OAuth2 server creation via Azure CLI in the APIM Bicep template
- Automate identity provider setup as part of infrastructure deployment
- Create a migration validation workflow that checks all artifacts before publishing
