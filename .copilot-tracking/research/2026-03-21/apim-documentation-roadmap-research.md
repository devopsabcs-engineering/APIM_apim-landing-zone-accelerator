<!-- markdownlint-disable-file -->
# Task Research: APIM Landing Zone Accelerator — Documentation, Migration & On-Demand Lab Roadmap

Comprehensive research on documenting the APIM migration from ADO to GitHub Actions, Classic v1 to BasicV2 SKU, APIops automation, and the on-demand lab environment strategy.

## Task Implementation Requests

* Document the full migration journey from Azure DevOps to GitHub Actions
* Document the APIM SKU migration from Classic Developer/Premium (v1) to BasicV2
* Create a roadmap for the on-demand lab environment
* Research automation gaps for v1-to-v2 migration artifacts
* Plan future capabilities: DR, workspaces, higher SKUs

## Scope and Success Criteria

* Scope: README.md rewrite, docs/ folder additions, roadmap creation
* Assumptions: BasicV2 dev and prod 006 instances are operational; 9 backend APIs deployed via deploy-all workflow
* Success Criteria:
  * README.md accurately describes the repo purpose and architecture
  * Migration lessons documented for future reference
  * Roadmap provides actionable next steps

## Key Discoveries

### Current Architecture (Instance 006 — BasicV2)

| Component | Dev | Prod |
|-----------|-----|------|
| APIM Instance | `apim-dev-006-cxfqm7rkx4ppi` | `apim-prod-006-xcilqlmt7zdw2` |
| Resource Group | `rg-apim-basicv2-dev-006` | `rg-apim-basicv2-prod-006` |
| SKU | BasicV2 | BasicV2 |
| Cost | ~$150/month | ~$150/month |
| Key Vault | `kv-apim-dev-006-cxfqm7rk` | `kv-apim-prod-006-xcilqlm` |

### Backend APIs (9 total, deployed via deploy-all.yml)

| API | Type | URL Pattern | Version Endpoint |
|-----|------|-------------|-----------------|
| Web App (OpenID Connect) | ASP.NET Core MVC | `app-web-app-*` | `/api/version` |
| Weather API | ASP.NET Core REST | `app-weather-api-*` | `/api/version` |
| Star Wars API | ASP.NET Core REST | `app-star-wars-api-*` | `/api/version` |
| SOAP API | ASP.NET Core SOAP | `app-soap-api-*` | `/api/version` |
| OData API | ASP.NET Core OData | `app-odata-api-*` | `/api/version` |
| Movie Reviews API | ASP.NET Core GraphQL | `app-movie-reviews-api-*` | `/api/version` |
| Flask App (MSAL Python) | Python Flask | `app-flask-*` | `/version` |
| Fast API | Python FastAPI | `fast-api-app-insights-*` | `/version` |
| Appointments API | Azure Functions | `func-appt-*` | `/api/version` |

### Migration Gaps Discovered (v1 → v2)

During publishing of 005 artifacts to 006 BasicV2 instances, the following items failed and had to be removed:

1. **External AAD Groups** — BasicV2 doesn't have an Azure AD identity provider configured by default
2. **OAuth2 Authorization Servers** — Referenced by API `authenticationSettings` but not present in fresh instance
3. **Key Vault References** — Named values pointed to 005 Key Vault; RBAC not propagated for 006
4. **User-scoped Subscriptions** — Referenced `ownerId` pointing to users that don't exist in 006
5. **Product-Group Associations** — Products referenced deleted external groups
6. **Instance-specific URLs** — `serviceUrl`, `developerPortalUrl` hardcoded to 005 instance names
7. **Workspaces** — Not supported on BasicV2 SKU
8. **Instrumentation Key** — Can't set via APIops when APIM logger validates it

### GitHub Workflows Created

| Workflow | Purpose |
|----------|---------|
| `deploy-all.yml` | Deploys all 9 backend APIs + wiki publish + screenshots |
| `deploy-apim-basicv2.yml` | Deploys APIM BasicV2 dev + prod with teardown |
| `run-extractor-006.yaml` | Extracts APIs from 006 APIM |
| `run-publisher-006.yaml` | Publishes artifacts to 006 dev → prod |
| `run-extractor-006.api-team-001.yaml` | Team 001 extractor |
| `run-extractor-006.api-team-002.yaml` | Team 002 extractor |
| `run-publisher-006.api-team-001.yaml` | Team 001 publisher |
| `run-publisher-006.api-team-002.yaml` | Team 002 publisher |

### Cost Analysis

| SKU | Monthly Cost | Features |
|-----|-------------|----------|
| Developer (v1) | ~$50 | VNet, no SLA |
| BasicV2 | ~$150 | No VNet, SLA, modern platform |
| StandardV2 | ~$350 | VNet injection, enhanced perf |
| Premium (v1) | ~$2,800+ | Workspaces, multi-region, VNet |

## Roadmap

### Phase 1: Current (Completed)
- [x] Migrate ADO pipelines to GitHub Actions
- [x] Deploy BasicV2 APIM dev + prod
- [x] Publish 15 APIs via APIops
- [x] Deploy 9 backend APIs with smoke tests + screenshots
- [x] Wiki deployment reports

### Phase 2: Automation Gaps
- [ ] Script OAuth2 authorization server creation for BasicV2
- [ ] Script AAD identity provider setup
- [ ] Automate user creation in fresh APIM instances
- [ ] Create subscription seeding script
- [ ] Build migration validation workflow

### Phase 3: On-Demand Lab
- [ ] Single workflow to create entire environment from scratch
- [ ] Automated teardown of all resources
- [ ] Cost tracking integration
- [ ] Lab provisioning time tracking

### Phase 4: Advanced Features
- [ ] DR scenario: deploy to second region
- [ ] StandardV2 SKU for VNet integration demos
- [ ] Premium SKU short-term provisioning for workspace demos
- [ ] Workspace gateway demonstrations (when available in Canada)
