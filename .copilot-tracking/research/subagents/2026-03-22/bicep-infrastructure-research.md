# Bicep Infrastructure Files and Resource Architecture — Research Document

## Research Topics

1. All main.bicep files and their Azure resource definitions
2. Workflow-to-Bicep mapping (which deploy workflow uses which main.bicep)
3. Resource group naming patterns
4. Module references and shared infrastructure
5. Existing diagram/visualization patterns in the repo
6. The `create-lab.yml` orchestration workflow

---

## 1. Main Bicep Files — Resource Inventory

### 1.1 `infra/appservice/main.bicep`

**Used by:** Weather API, Star Wars API, SOAP API, OData API, Movie API, Web App (6 apps)

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.Web/serverfarms@2023-12-01` | `appServicePlan` | Linux App Service Plan (B1 SKU) |
| `Microsoft.Web/sites@2023-12-01` | `appService` | Linux container-based App Service |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01` | `appService::scm` | SCM basic auth (child resource) |
| `Microsoft.OperationalInsights/workspaces@2023-09-01` | `logAnalytics` | Log Analytics workspace |
| `Microsoft.Insights/components@2020-02-02` | `appInsights` | Application Insights |
| `Microsoft.ContainerRegistry/registries@2023-11-01-preview` | `containerRegistry` | Azure Container Registry (Basic SKU) |
| `Microsoft.Storage/storageAccounts@2023-05-01` | `storageAccount` | Storage Account (conditional, `addStorageAccount` param) |
| `Microsoft.Storage/storageAccounts/blobServices@2023-05-01` | `storageAccount::blobServices` | Blob service (conditional child) |
| `Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01` | `storageAccount::blobServices::container` | Blob container (conditional child) |

**Key Parameters:**
- `baseName` — drives naming convention (e.g., `weather-api`, `star-wars-api`)
- `imageName` — Docker image name for container deployment
- `addAzureAdAppSettings` — toggles Azure AD app settings (used only by Web App)
- `addStorageAccount` — toggles storage account creation (used only by Web App)
- `location` — defaults to `resourceGroup().location`

**Naming Convention:** `app-{baseName}-{uniqueString}`, `asp-{baseName}-{uniqueString}`, `cr{baseName}{uniqueString}`, `appi-{baseName}-{uniqueString}`, `log-{baseName}-{uniqueString}`

**Dependencies:** AppService → AppServicePlan, AppService → AppInsights, AppService → ContainerRegistry, AppInsights → LogAnalytics (via WorkspaceResourceId)

**Module References:** None — self-contained template

---

### 1.2 `infra/webapp/main.bicep`

**Used by:** SOAP API (the default `baseName` is `soap-api`, but this template is a simpler alternative — currently references show the SOAP workflow uses `infra/appservice/main.bicep` instead)

**Status:** Legacy/alternate template. Not referenced by any current workflow.

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.Web/serverfarms@2023-12-01` | `appServicePlan` | Linux App Service Plan (B1 SKU) |
| `Microsoft.Web/sites@2023-12-01` | `appService` | Linux App Service (code-based, not container) |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01` | `appService::basicPublishingCredentialsPolicies` | SCM basic auth (child resource) |
| `Microsoft.OperationalInsights/workspaces@2023-09-01` | `logAnalytics` | Log Analytics workspace |
| `Microsoft.Insights/components@2020-02-02` | `appInsights` | Application Insights |

**Key Differences from `infra/appservice/main.bicep`:**
- No Container Registry
- No Storage Account
- Uses code-based deployment (linuxFxVersion: `DOTNETCORE|8.0`) not container
- Simpler template overall

**Module References:** None

---

### 1.3 `infra/fnapp/main.bicep`

**Used by:** Appointments API

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.Network/virtualNetworks@2024-01-01` | `vnet` | VNet with 2 subnets (func + private endpoints) |
| `Microsoft.Network/privateDnsZones@2024-06-01` | `privateDnsZones` (×4) | Private DNS zones for blob/queue/table/file |
| `Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01` | `privateDnsZoneLinks` (×4) | DNS zone VNet links |
| `Microsoft.OperationalInsights/workspaces@2023-09-01` | `logAnalytics` | Log Analytics workspace |
| `Microsoft.ContainerRegistry/registries@2023-11-01-preview` | `containerRegistry` | Azure Container Registry (Basic SKU) |
| `Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31` | `managedIdentity` | User-assigned managed identity |
| `Microsoft.Storage/storageAccounts@2023-05-01` | `storageAccount` | Storage Account (no shared key, no public access, private) |
| `Microsoft.Storage/storageAccounts/tableServices@2023-05-01` | `storageAccount::tableService` | Table service (child) |
| `Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01` | `storageAccount::tableService::table` | Appointments table (child) |
| `Microsoft.Network/privateEndpoints@2024-01-01` | `storagePrivateEndpoints` (×4) | Private endpoints for blob/queue/table/file |
| `Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01` | `privateEndpointDnsGroups` (×4) | DNS zone groups for PEs |
| `Microsoft.Web/serverfarms@2024-04-01` | `hostingPlan` | App Service Plan (S1 Standard) |
| `Microsoft.Insights/components@2020-02-02` | `applicationInsight` | Application Insights |
| `Microsoft.Web/sites@2024-04-01` | `functionApp` | Linux Function App (container-based, VNet-integrated) |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiStorageBlobDataOwnerRole` | RBAC: UAMI → Storage Blob Data Owner |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiStorageAccountContributorRole` | RBAC: UAMI → Storage Account Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiStorageQueueDataContributorRole` | RBAC: UAMI → Storage Queue Data Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiStorageTableDataContributorRole` | RBAC: UAMI → Storage Table Data Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiStorageFileDataContributorRole` | RBAC: UAMI → Storage File Data Privileged Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `uamiAcrPullRole` | RBAC: UAMI → ACR Pull |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `sysStorageBlobDataOwnerRole` | RBAC: System Identity → Storage Blob Data Owner |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `sysStorageAccountContributorRole` | RBAC: System Identity → Storage Account Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `sysStorageQueueDataContributorRole` | RBAC: System Identity → Storage Queue Data Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `sysStorageTableDataContributorRole` | RBAC: System Identity → Storage Table Data Contributor |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `sysStorageFileDataContributorRole` | RBAC: System Identity → Storage File Data Privileged Contributor |

**Total unique resource types:** 10 resource types, ~24 resource instances

**Key Parameters:** `instanceNumber`, `appointmentTableName`, `storageAccountType`, `functionWorkerRuntime`

**Security Features:**
- Storage Account: `allowSharedKeyAccess: false`, `allowBlobPublicAccess: false`, `publicNetworkAccess: 'Disabled'`
- Identity-based AzureWebJobsStorage (no connection strings)
- Private Endpoints for all storage sub-resources
- VNet integration for Function App

**Module References:** None — self-contained template

---

### 1.4 `infra/api-management-basicv2/main.bicep`

**Used by:** APIM BasicV2 deployment (Dev + Prod environments)

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.ApiManagement/service@2024-06-01-preview` | `apiManagement` | API Management service (BasicV2 SKU) |
| `Microsoft.OperationalInsights/workspaces@2023-09-01` | `logAnalyticsWorkspace` | Log Analytics workspace |
| `Microsoft.Insights/components@2020-02-02` | `applicationInsights` | Application Insights |
| `Microsoft.ApiManagement/service/namedValues@2024-06-01-preview` | `namedValueAppInsightsSecret` | Named value for instrumentation key |
| `Microsoft.ApiManagement/service/loggers@2024-06-01-preview` | `apimLogger` | APIM logger linked to App Insights |
| `Microsoft.KeyVault/vaults@2024-04-01-preview` | `keyVault` | Key Vault (RBAC-enabled, soft delete) |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `keyVaultRoleAssignment` | RBAC: APIM identity → Key Vault Secrets User |
| `Microsoft.KeyVault/vaults/secrets@2024-04-01-preview` | `secretAppInsights` | Key Vault secret for App Insights key |
| `Microsoft.ApiManagement/service/authorizationServers@2024-06-01-preview` | `oAuth2Server` | OAuth2 authorization server (conditional) |

**Key Parameters:**
- `publisherEmail`, `publisherName` — APIM publisher info
- `sku` — `BasicV2` or `StandardV2`
- `environmentName` — `dev`, `qa`, or `prod`
- `instanceNumber` — drives naming
- `createOAuth2Server`, `oAuth2ClientId` — conditional OAuth2 server

**Naming Convention:** `apim-{env}-{instance}-{uniqueString}`, `appi-apim-{env}-{instance}-{uniqueString}`, `log-apim-{env}-{instance}-{uniqueString}`, `kv-apim-{env}-{instance}-{uniqueString}` (truncated to 24 chars)

**Security Features:**
- APIM: TLS 1.0/1.1/SSL 3.0 disabled, HTTP/2 enabled, minimum API version constraint
- Key Vault: RBAC authorization, soft delete enabled, 90-day retention
- System-assigned managed identity on APIM

**Module References:** None — self-contained template

---

### 1.5 `src/fast-api-app-insights/main.bicep`

**Used by:** Fast API

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.Web/serverfarms@2023-01-01` | `appServicePlan` | Linux App Service Plan (B1 Basic) |
| `Microsoft.Insights/components@2020-02-02` | `appInsights` | Application Insights |
| `Microsoft.Web/sites@2023-01-01` | `webApp` | Linux App Service (Python 3.13, uvicorn) |

**Key Parameters:** `appName`, `skuName`, `deploymentEnvironment`, `appVersion`

**Notable:** Uses OpenTelemetry-based instrumentation (`OTEL_*` env vars), startup command: `python -m uvicorn main:app --host 0.0.0.0 --port 8000`

**Module References:** None — self-contained template

---

### 1.6 `src/msal-python-soln/python-flask-webapp/main.bicep`

**Used by:** Flask App

| Azure Resource Type | Symbolic Name | Purpose |
|---|---|---|
| `Microsoft.Insights/components@2020-02-02` | `appInsights` | Application Insights |
| `Microsoft.Web/sites@2024-11-01` | `webApp` | Linux App Service (Python 3.13) |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-11-01` | `webApp::scm` | SCM basic auth (child resource) |
| `Microsoft.Web/serverfarms@2024-11-01` | `hostingPlan` | Linux App Service Plan (B1 Basic) |
| `Microsoft.KeyVault/vaults@2025-05-01` | `keyVault` | Key Vault (RBAC-enabled) |
| `Microsoft.KeyVault/vaults/secrets@2025-05-01` | `secret` | Client Secret stored in Key Vault |
| `Microsoft.Authorization/roleAssignments@2022-04-01` | `kvRoleAssignment` | RBAC: Web App identity → Key Vault Secrets User |

**Key Parameters:** `webAppName`, `keyVaultName`, `pythonVersion`, `secretName`, `secretValue`

**Notable:**
- MSAL (Microsoft Authentication Library) integration
- Key Vault reference for CLIENT_SECRET app setting
- System-assigned managed identity with Key Vault Secrets User role

**Module References:** None — self-contained template

---

## 2. Workflow-to-Bicep Mapping

| Workflow | App | Bicep Template | Resource Group Pattern | Default Instance |
|---|---|---|---|---|
| `deploy-weather-api.yml` | Weather API | `infra/appservice/main.bicep` | `rg-weather-appservice-linux-{instance}` | `005` |
| `deploy-star-wars-api.yml` | Star Wars API | `infra/appservice/main.bicep` | `rg-star-wars-appservice-linux-{instance}` | `003` |
| `deploy-soap-api.yml` | SOAP API | `infra/appservice/main.bicep` | `rg-soap-appservice-linux-{instance}` | `007` |
| `deploy-odata-api.yml` | OData API | `infra/appservice/main.bicep` | `rg-odata-appservice-linux-{instance}` | `002` |
| `deploy-movie-api.yml` | Movie API | `infra/appservice/main.bicep` | `rg-movies-appservice-linux-{instance}` | `006` |
| `deploy-web-app.yml` | Web App | `infra/appservice/main.bicep` | `rg-web-appservice-linux-{instance}` | `005` |
| `deploy-flask-app.yml` | Flask App | `src/msal-python-soln/python-flask-webapp/main.bicep` | `rg-msal-python-soln` | N/A (fixed) |
| `deploy-fast-api.yml` | Fast API | `src/fast-api-app-insights/main.bicep` | `rg-fast-api-app-insights-001` | N/A (fixed) |
| `deploy-appointments-api.yml` | Appointments API | `infra/fnapp/main.bicep` | `rg-appointments-fnapp-linux-{instance}` | `003` |
| `deploy-apim-basicv2.yml` | APIM BasicV2 | `infra/api-management-basicv2/main.bicep` | `rg-apim-basicv2-{env}-{instance}` | `006` |

### Resource Group Naming Patterns

- **Container-based .NET APIs:** `rg-{app-name}-appservice-linux-{instance_number}`
- **Python apps (Flask/FastAPI):** Fixed names (`rg-msal-python-soln`, `rg-fast-api-app-insights-001`)
- **Function Apps:** `rg-{app-name}-fnapp-linux-{instance_number}`
- **APIM:** `rg-apim-basicv2-{environment}-{instance_number}` (e.g., `rg-apim-basicv2-dev-006`, `rg-apim-basicv2-prod-006`)

---

## 3. Bicep Template Category Summary

### Template A: `infra/appservice/main.bicep` (Container-based App Service)
- **Apps:** Weather API, Star Wars API, SOAP API, OData API, Movie API, Web App
- **Resource count per deployment:** 5-8 resources (App Service Plan, App Service, Log Analytics, App Insights, Container Registry, optional Storage Account)
- **Total for 6 apps:** ~30-40 Azure resources

### Template B: `infra/fnapp/main.bicep` (Secure Function App)
- **Apps:** Appointments API
- **Resource count per deployment:** ~24 resources (VNet, DNS zones, DNS links, Private Endpoints, DNS groups, Storage, Table Service, Table, ACR, Managed Identity, App Service Plan, App Insights, Log Analytics, Function App, 12 RBAC role assignments)
- **Most complex template** — enterprise-grade security with VNet integration and private endpoints

### Template C: `infra/api-management-basicv2/main.bicep` (APIM)
- **Apps:** APIM Dev, APIM Prod (deployed twice with different parameters)
- **Resource count per deployment:** 7-8 resources (APIM service, Log Analytics, App Insights, Named Value, Logger, Key Vault, RBAC, KV Secret, optional OAuth2 server)
- **Total for 2 environments:** ~16 Azure resources

### Template D: `src/fast-api-app-insights/main.bicep` (Lightweight Python App Service)
- **Apps:** Fast API
- **Resource count per deployment:** 3 resources (App Service Plan, App Insights, App Service)
- **Simplest template**

### Template E: `src/msal-python-soln/python-flask-webapp/main.bicep` (Python + Key Vault)
- **Apps:** Flask App
- **Resource count per deployment:** 6 resources (App Insights, App Service, App Service Plan, Key Vault, Secret, RBAC)

### Template F: `infra/webapp/main.bicep` (Legacy/unused)
- **Apps:** None (not referenced by any current workflow)
- **Resource count per deployment:** 4 resources (App Service Plan, App Service, Log Analytics, App Insights)

---

## 4. Module and Shared Infrastructure Analysis

### Custom Bicep Templates (under `infra/` and `src/`)

**No shared modules are used.** All 5 active main.bicep templates are self-contained — they define all resources inline without referencing external Bicep modules.

### Reference Implementation Bicep (under `reference-implementations/`)

The `reference-implementations/AppGW-IAPIM-Func/bicep/` directory uses extensive module references (e.g., `azmon.bicep`, `createvmwindows.bicep`, certificate modules). This is the original Microsoft landing zone accelerator architecture and is **separate from the custom lab deployments**.

### Infra Folder Structure

```text
infra/
├── api-management-basicv2/        ← APIM deployment (active)
│   ├── main.bicep
│   ├── main.json
│   ├── main.parameters.dev-006.json
│   └── main.parameters.prod-006.json
├── appservice/                     ← Container-based App Service (active, used by 6 apps)
│   ├── main.bicep
│   └── deploy*.ps1 (legacy scripts)
├── fnapp/                          ← Function App (active, appointments)
│   ├── main.bicep
│   ├── main.json
│   └── deployAppointmentApp.ps1
├── webapp/                         ← Simple App Service (inactive/legacy)
│   ├── main.bicep
│   └── deploySoapApp.ps1
├── api-management-create-with-external-vnet-publicip-stv2/  ← Enterprise APIM (separate)
├── apim-b2c/                       ← B2C-related (separate)
├── certificates/                   ← Certificate resources
├── scripts/                        ← Infrastructure scripts
├── securefiles/                    ← Secure file templates
└── variables/                      ← Variable group templates
```

---

## 5. Existing Visualization and Diagram Patterns

### Current Diagrams

- **`docs/assets/diagrams/apimADSv2.{vsdx,svg,png,drawio}`** — Architecture design session diagram for the AppGW-IAPIM-Func reference implementation
- **`docsLZ/images/arch.png`** — Landing zone architecture diagram
- **Microsoft Learn external reference:** `https://learn.microsoft.com/azure/architecture/example-scenario/devops/media/automated-api-deployments-architecture-diagram.png`

### Mermaid Diagrams

**No Mermaid diagrams exist anywhere in the repository.** No `mermaid` keyword found in any file.

### Format Preferences

The repo uses:
- Visio (`.vsdx`) — primary diagram format
- Draw.io (`.drawio`) — alternate editable format
- SVG/PNG — rendered output for docs
- No text-based diagram formats (no Mermaid, no PlantUML, no D2)

---

## 6. Create-Lab Workflow Analysis (`create-lab.yml`)

The `create-lab.yml` is a comprehensive orchestration workflow that deploys the entire lab environment:

### Execution Flow

```text
record-start-time
    ├── deploy-apim (calls deploy-apim-basicv2.yml)
    │     → Deploys APIM Dev + Prod + seeds demo data
    │
    └── deploy-apis (calls deploy-all.yml, parallel with APIM)
          → Deploys all 9 backend APIs in parallel
          
    ├── publish-apiops-dev (after both deploy-apim and deploy-apis)
    │     → Publishes APIops artifacts to Dev APIM
    │
    └── publish-apiops-prod (after publish-apiops-dev)
          → Publishes APIops artifacts to Prod APIM

    └── lab-summary (always runs)
          → Writes comprehensive job summary with cost estimates
```

### Parameters
- `instance_number` (default: `006`)
- `location` (default: `canadacentral`)
- `deploy_apis` (default: `true`)

### Total Resources Deployed by Create-Lab

| Category | Count | Details |
|---|---|---|
| APIM Dev | ~8 | APIM + Log Analytics + App Insights + KV + RBAC + Logger + Named Value + Secret |
| APIM Prod | ~8 | Same as Dev |
| Weather API | ~6 | ASP + App Service + ACR + Log Analytics + App Insights + SCM |
| Star Wars API | ~6 | Same pattern |
| SOAP API | ~6 | Same pattern |
| OData API | ~6 | Same pattern |
| Movie API | ~6 | Same pattern |
| Web App | ~8 | Same + Storage Account + Blob Service + Container |
| Flask App | ~6 | ASP + App Service + App Insights + KV + Secret + RBAC |
| Fast API | ~3 | ASP + App Service + App Insights |
| Appointments API | ~24 | VNet + DNS + PEs + Storage + ACR + Identity + Func + RBAC... |
| **Total** | **~93** | **Approximate Azure resource count** |

---

## 7. Resource Type Summary Across All Templates

| Resource Type | Templates Using It | Count |
|---|---|---|
| `Microsoft.Web/serverfarms` | appservice, fnapp, fast-api, flask, webapp | 5 templates |
| `Microsoft.Web/sites` | appservice, fnapp, fast-api, flask, webapp | 5 templates |
| `Microsoft.Insights/components` | All 6 templates | 6 templates |
| `Microsoft.OperationalInsights/workspaces` | appservice, fnapp, apim, webapp | 4 templates |
| `Microsoft.ContainerRegistry/registries` | appservice, fnapp | 2 templates |
| `Microsoft.KeyVault/vaults` | apim, flask | 2 templates |
| `Microsoft.KeyVault/vaults/secrets` | apim, flask | 2 templates |
| `Microsoft.Authorization/roleAssignments` | fnapp (12×), apim (1×), flask (1×) | 3 templates |
| `Microsoft.ApiManagement/service` | apim | 1 template |
| `Microsoft.Network/virtualNetworks` | fnapp | 1 template |
| `Microsoft.Network/privateDnsZones` | fnapp | 1 template |
| `Microsoft.Network/privateEndpoints` | fnapp | 1 template |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | fnapp | 1 template |
| `Microsoft.Storage/storageAccounts` | appservice (conditional), fnapp | 2 templates |

---

## 8. Discovered Research Topics

### Completed

- [x] All main.bicep files read and documented
- [x] Azure resource types cataloged per template
- [x] Workflow-to-Bicep mapping established
- [x] Resource group naming patterns documented
- [x] Module dependency analysis completed (no shared modules)
- [x] Existing diagram/visualization patterns documented
- [x] Create-lab.yml workflow analyzed
- [x] Total resource count estimated (~93 resources)

### Follow-On Research Recommendations

- [ ] Review `infra/api-management-basicv2/main.parameters.dev-006.json` and `main.parameters.prod-006.json` for environment-specific parameter differences
- [ ] Analyze the APIops publisher workflows (`run-publisher-with-env-006.yaml`) to understand how API definitions are pushed to APIM
- [ ] Investigate the `reference-implementations/AppGW-IAPIM-Func/bicep/main.bicep` for comparison with the BasicV2 approach
- [ ] Check if the `infra/webapp/main.bicep` template should be removed or updated as it appears unused
- [ ] Consider creating Mermaid diagrams for the infrastructure since none exist today

---

## 9. Clarifying Questions

None — all research questions were answerable from workspace content.
