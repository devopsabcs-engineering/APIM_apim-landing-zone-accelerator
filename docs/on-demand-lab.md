# On-Demand Lab Environment Runbook

## Overview

This runbook describes how to create and tear down the complete APIM demo environment on demand. The goal is to minimize costs by only running resources when actively demonstrating or developing.

## Full Environment Components

| Component | Workflow | Deploy Time | Monthly Cost |
|-----------|----------|-------------|-------------|
| APIM BasicV2 Dev | `deploy-apim-basicv2.yml` | ~5 minutes | ~$150 |
| APIM BasicV2 Prod | `deploy-apim-basicv2.yml` | ~5 minutes | ~$150 |
| 9 Backend APIs | `deploy-all.yml` | ~15 minutes | ~$90 |
| API Configurations | `run-publisher-006.yaml` | ~5 minutes | $0 |

## Create Environment

### Step 1: Deploy APIM Infrastructure

1. Go to **Actions** > **Deploy APIM BasicV2**
2. Set inputs:
   - `deploy_dev: true`
   - `deploy_prod: true`
   - `teardown_dev: false`
   - `teardown_prod: false`
3. Approve `APIM_BasicV2_Dev` and `APIM_BasicV2_Prod` environments
4. Wait for completion (~5 minutes each, runs in parallel)

### Step 2: Deploy Backend APIs

1. Go to **Actions** > **Deploy All Apps and APIs**
2. Set inputs:
   - `deploy_infra: true`
   - `teardown: false`
3. Approve each environment as prompted
4. Wait for completion (~15 minutes, all 9 deploy in parallel)
5. Check the **wiki deployment report** for smoke test results and screenshots

### Step 3: Publish API Configurations

1. Go to **Actions** > **Run - Publisher - 006**
2. Set inputs:
   - `COMMIT_ID_CHOICE: publish-all-artifacts-in-repo`
   - `API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: artifacts.dev-006`
3. Approve `dev-006` environment, then `prod-006`
4. Verify APIs appear in the APIM developer portal

### Step 4: Verify

- Check APIM developer portal: `https://<apim-name>.developer.azure-api.net`
- Test APIs via the APIM gateway
- Review smoke test results in workflow summaries and wiki

## Tear Down Environment

### Step 1: Tear Down Backend APIs

1. Go to **Actions** > **Deploy All Apps and APIs**
2. Set `teardown: true`
3. Approve `APIM_Teardown_All` environment

### Step 2: Tear Down APIM Infrastructure

1. Go to **Actions** > **Deploy APIM BasicV2**
2. Set `teardown_dev: true` and `teardown_prod: true`
3. Set `deploy_dev: true` and `deploy_prod: true` (required for teardown job dependencies)
4. Approve teardown environments

### Resource Groups Deleted

| Resource Group | Contents |
|----------------|----------|
| `rg-apim-basicv2-dev-006` | APIM Dev, Key Vault, App Insights |
| `rg-apim-basicv2-prod-006` | APIM Prod, Key Vault, App Insights |
| `rg-web-appservice-linux-005` | Web App + ACR |
| `rg-weather-appservice-linux-005` | Weather API + ACR |
| `rg-star-wars-appservice-linux-003` | Star Wars API + ACR |
| `rg-soap-appservice-linux-007` | SOAP API + ACR |
| `rg-odata-appservice-linux-002` | OData API + ACR |
| `rg-movies-appservice-linux-006` | Movie Reviews API + ACR |
| `rg-msal-python-soln` | Flask App + Key Vault |
| `rg-fast-api-app-insights-001` | Fast API |
| `rg-appointments-fnapp-linux-003` | Appointments Function App |

## Cost Optimization

| Strategy | Savings |
|----------|---------|
| Tear down after demo | Save ~$390/month |
| Keep only APIM, tear down APIs | Save ~$90/month |
| Use APIM only during business hours | Not supported (no auto-scale to zero) |
| Deploy Premium SKU only for workspace demos | ~$2,800/month for short demos |

## Prerequisites

### GitHub Secrets and Environments

Ensure these are configured before first deployment:

**Repository Secrets** (for backend APIs):
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

**Environment Secrets** (for APIM):
- `APIM_BasicV2_Dev`: `APIM_AZURE_CLIENT_ID`, `APIM_AZURE_TENANT_ID`, `APIM_AZURE_SUBSCRIPTION_ID`
- `APIM_BasicV2_Prod`: same pattern

**Environment Secrets** (for APIops):
- `dev-006`: `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- `prod-006`: same pattern

**Environment Variables** (for APIops):
- `dev-006`: `AZURE_RESOURCE_GROUP_NAME`, `API_MANAGEMENT_SERVICE_NAME`
- `prod-006`: same pattern
