# APIM Landing Zone Accelerator

Azure API Management landing zone accelerator with APIops automation, multi-environment CI/CD, and on-demand lab provisioning.

## Overview

This repository demonstrates enterprise-grade API Management practices using Azure APIM BasicV2 SKU with GitHub Actions for infrastructure deployment and APIops for API lifecycle management.

### Architecture

```text
GitHub Actions
├── Infrastructure (Bicep)
│   ├── APIM BasicV2 Dev + Prod (instance 006)
│   ├── 9 Backend API App Services / Functions
│   └── Supporting resources (Key Vault, App Insights, Log Analytics)
├── APIops (Extractor + Publisher)
│   ├── Extract from Dev APIM → Git artifacts
│   ├── Publish artifacts → Dev APIM → Prod APIM
│   └── Team-scoped pipelines (Team 001, Team 002)
└── Deployment Reports
    ├── Smoke tests with version checks
    ├── Screenshots (Puppeteer)
    └── GitHub Wiki reports
```

### Backend APIs

| API | Technology | Smoke Test |
|-----|-----------|------------|
| Web App (OpenID Connect) | ASP.NET Core MVC | Home Page |
| Weather API | ASP.NET Core REST | Swagger UI |
| Star Wars API | ASP.NET Core REST | Swagger UI |
| SOAP API | ASP.NET Core SOAP (SoapCore) | WSDL |
| OData API | ASP.NET Core OData | $metadata |
| Movie Reviews API | ASP.NET Core + GraphQL (Playground) | Swagger + GraphQL |
| Flask App (MSAL Python) | Python Flask + OpenTelemetry | Home Page |
| Fast API | Python FastAPI + App Insights | Health + Docs |
| Appointments API | Azure Functions (.NET 8) | Function endpoint |

### APIM Instances

| Instance | SKU | Environment | Purpose |
|----------|-----|-------------|---------|
| 005 | Premium (Classic v1) | Dev + Prod | Legacy with VNet, workspaces |
| 006 | BasicV2 | Dev + Prod | Modern, cost-efficient |
| 007 | BasicV2 | Dev + Prod | APIops CLI promotion lab with an AI gateway (token limits, content safety, token metrics) ([runbook](docs/apim-007-apiops-cli.md)) |

## Quick Start

### Deploy Everything from Scratch

1. **Deploy APIM infrastructure** — Run `Deploy APIM BasicV2` workflow
2. **Deploy backend APIs** — Run `Deploy All Apps and APIs` workflow
3. **Publish API configurations** — Run `Run - Publisher - 006` with `publish-all-artifacts-in-repo`

### Tear Down Everything

1. Run `Deploy All Apps and APIs` with `teardown: true`
2. Run `Deploy APIM BasicV2` with `teardown_dev: true` and `teardown_prod: true`

## GitHub Workflows

### Infrastructure

| Workflow | Purpose |
|----------|---------|
| `deploy-apim-basicv2.yml` | APIM BasicV2 dev + prod with teardown |
| `deploy-all.yml` | All 9 backend APIs + wiki report |
| `deploy-web-app.yml` | Web App (OpenID Connect) |
| `deploy-weather-api.yml` | Weather API |
| `deploy-star-wars-api.yml` | Star Wars API |
| `deploy-soap-api.yml` | SOAP API |
| `deploy-odata-api.yml` | OData API |
| `deploy-movie-api.yml` | Movie Reviews API |
| `deploy-flask-app.yml` | Flask App (MSAL Python) |
| `deploy-fast-api.yml` | Fast API |
| `deploy-appointments-api.yml` | Appointments Azure Function |

### APIops (Instance 006 — BasicV2)

| Workflow | Purpose |
|----------|---------|
| `run-extractor-006.yaml` | Extract APIs from dev APIM |
| `run-publisher-006.yaml` | Publish to dev → prod |
| `run-extractor-006.api-team-001.yaml` | Team 001 extraction |
| `run-extractor-006.api-team-002.yaml` | Team 002 extraction |
| `run-publisher-006.api-team-001.yaml` | Team 001 publishing |
| `run-publisher-006.api-team-002.yaml` | Team 002 publishing |

### APIops (Instance 005 — Legacy)

| Workflow | Purpose |
|----------|---------|
| `run-extractor-005.yaml` | Extract APIs from legacy APIM |
| `run-publisher-005.yaml` | Publish to legacy dev → prod |

## Configuration Files

| File | Purpose |
|------|---------|
| `configuration.extractor.dev-006.yaml` | Dev extraction filter for 006 |
| `configuration.extractor.dev-006.api-team-001.yaml` | Team 001 extraction filter |
| `configuration.extractor.dev-006.api-team-002.yaml` | Team 002 extraction filter |
| `configuration.prod-006.yaml` | Prod environment overrides for 006 |

## Artifact Folders

| Folder | Purpose |
|--------|---------|
| `artifacts.dev-006/` | Extracted dev API artifacts for BasicV2 |
| `artifacts.dev-006.api-team-001/` | Team 001 scoped artifacts |
| `artifacts.dev-006.api-team-002/` | Team 002 scoped artifacts |
| `artifacts.prod-006/` | Prod API artifacts for BasicV2 |

## GitHub Environments Required

### Infrastructure Deployment

| Environment | Secrets |
|-------------|---------|
| `APIM_BasicV2_Dev` | `APIM_AZURE_CLIENT_ID`, `APIM_AZURE_TENANT_ID`, `APIM_AZURE_SUBSCRIPTION_ID` |
| `APIM_BasicV2_Prod` | Same pattern |
| `APIM_BasicV2_Dev_Teardown` | Same pattern |
| `APIM_BasicV2_Prod_Teardown` | Same pattern |

### APIops

| Environment | Secrets | Variables |
|-------------|---------|-----------|
| `dev-006` | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | `AZURE_RESOURCE_GROUP_NAME`, `API_MANAGEMENT_SERVICE_NAME` |
| `prod-006` | Same pattern | Same pattern |

### Backend API Deployment

All backend API workflows use repo-level secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

## Cost Considerations

| Configuration | Monthly Cost | Notes |
|---------------|-------------|-------|
| BasicV2 Dev + Prod | ~$300 | Always-on |
| 9 Backend APIs (B1 App Service) | ~$90 | Tear down when not needed |
| On-demand (deploy + teardown) | Pay per hour | Recommended for demos |

## Documentation

- [APIops Lab Guide](docs/) — Step-by-step APIops walkthrough
- [Landing Zone Deployment](docsLZ/) — Enterprise-scale APIM deployment
- [Migration Guide](docs/migration-v1-to-basicv2.md) — Classic to BasicV2 migration
- [On-Demand Lab Runbook](docs/on-demand-lab.md) — Create and tear down environments

## Roadmap

See [docs/roadmap.md](docs/roadmap.md) for the detailed roadmap.

## Related Resources

- [Azure APIops](https://github.com/Azure/apiops)
- [APIM Landing Zone Accelerator (upstream)](https://github.com/Azure/apim-landing-zone-accelerator)
- [Azure APIM BasicV2 Documentation](https://learn.microsoft.com/en-us/azure/api-management/v2-service-tiers-overview)
