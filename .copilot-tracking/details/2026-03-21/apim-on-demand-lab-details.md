<!-- markdownlint-disable-file -->
# Implementation Details: APIM On-Demand Lab — Phase 2 & 3

## Context Reference

Sources: .copilot-tracking/research/2026-03-21/apim-documentation-roadmap-research.md, docs/roadmap.md, docs/on-demand-lab.md

## Implementation Phase 1: Artifact Sanitizer Script

<!-- parallelizable: true -->

### Step 1.1: Create PowerShell script `scripts/sanitize-artifacts-for-v2.ps1`

Create a script that cleans v1-specific references from artifact folders before publishing to BasicV2 instances. The script addresses all 8 migration gaps discovered during the v1-to-v2 migration.

Files:
* `scripts/sanitize-artifacts-for-v2.ps1` — New file

The script performs these operations:
1. Remove external AAD groups (type=external in groupInformation.json)
2. Remove product-group associations referencing deleted external groups
3. Remove all subscriptions (contain instance-specific user/product references)
4. Clear `authenticationSettings.oAuth2` from all API apiInformation.json files
5. Remove Key Vault references from named values, replace with placeholder values
6. Remove `instrumentationKey` named value (managed by Bicep)
7. Remove workspace artifacts (not supported on BasicV2)
8. Update instance-specific URLs (serviceUrl, developerPortalUrl)

Parameters:
* `-ArtifactPath` — Root path to the artifact folder to sanitize
* `-TargetApimName` — APIM instance name to update URLs to
* `-WhatIf` — Preview changes without modifying files

Success criteria:
* Script processes all 8 migration gap categories
* Running publisher after sanitization succeeds without errors
* Script is idempotent (safe to run multiple times)

### Step 1.2: Integrate sanitizer into publisher-with-env-006.yaml

Add a step before the publisher execution that runs the sanitizer script.

Files:
* `.github/workflows/run-publisher-with-env-006.yaml` — Add pre-publish step

Add a step after checkout that runs:
```yaml
- name: Sanitize artifacts for BasicV2
  run: |
    pwsh scripts/sanitize-artifacts-for-v2.ps1 \
      -ArtifactPath "${{ github.workspace }}/${{ inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}" \
      -TargetApimName "${{ vars.API_MANAGEMENT_SERVICE_NAME }}"
  shell: bash
```

Success criteria:
* Publisher 006 workflow succeeds without manual intervention
* Sanitizer runs before publisher in all publisher jobs

Dependencies:
* Step 1.1 completion

### Step 1.3: Validate phase changes

Run publisher 006 workflow with `publish-all-artifacts-in-repo` to confirm sanitized artifacts deploy successfully.

## Implementation Phase 2: APIM Post-Deployment Configuration

<!-- parallelizable: true -->

### Step 2.1: Add OAuth2 authorization server to BasicV2 Bicep template

Add an OAuth2 authorization server resource to the APIM Bicep template so APIs with OAuth2 authentication settings can be published.

Files:
* `infra/api-management-basicv2/main.bicep` — Add authorizationServer resource

Add a Bicep resource:
```bicep
param createOAuth2Server bool = true
param oAuth2ClientId string = ''

resource oAuth2Server 'Microsoft.ApiManagement/service/authorizationServers@2024-06-01-preview' = if (createOAuth2Server && oAuth2ClientId != '') {
  parent: apiManagement
  name: 'weatherappoauth'
  properties: {
    displayName: 'Weather App OAuth'
    clientRegistrationEndpoint: 'https://login.microsoftonline.com'
    authorizationEndpoint: '${environment().authentication.loginEndpoint}${tenant().tenantId}/oauth2/v2.0/authorize'
    tokenEndpoint: '${environment().authentication.loginEndpoint}${tenant().tenantId}/oauth2/v2.0/token'
    clientId: oAuth2ClientId
    grantTypes: ['authorizationCode']
    authorizationMethods: ['GET', 'POST']
  }
}
```

Success criteria:
* Bicep deploys without errors
* APIM portal shows the OAuth2 authorization server

### Step 2.2: Add Azure CLI post-deploy step for AAD identity provider

Add post-deployment Azure CLI commands to configure AAD identity provider on the APIM instance.

Files:
* `.github/workflows/deploy-apim-basicv2.yml` — Add post-deploy step in deploy-dev and deploy-prod jobs

The step uses Azure CLI to configure the identity provider:
```bash
az apim identity-provider create \
  --resource-group $RG \
  --service-name $APIM_NAME \
  --identity-provider-type aad \
  --client-id "$AAD_CLIENT_ID" \
  --client-secret "$AAD_CLIENT_SECRET" \
  --allowed-tenants "$TENANT_ID"
```

This is conditional on secrets being present — if no `AAD_CLIENT_ID` secret exists, skip the step.

Success criteria:
* Identity provider visible in APIM portal
* External AAD groups can be created

Dependencies:
* App registration for APIM developer portal exists

### Step 2.3: Create demo user and subscription seeding script

Create a script that seeds demo users and product subscriptions in a fresh APIM instance.

Files:
* `scripts/seed-apim-users-and-subscriptions.ps1` — New file

The script:
1. Creates 2 demo users (admin user, regular user) via Azure CLI
2. Creates subscriptions for each product (starter, unlimited, conference, etc.)
3. Creates an all-APIs subscription for testing
4. Outputs subscription keys for use in testing

Parameters:
* `-ResourceGroup` — Resource group name
* `-ApimName` — APIM service name
* `-UserEmail` — Email for the demo user

Success criteria:
* Users created in APIM
* Subscriptions created for all published products
* Subscription keys retrievable

### Step 2.4: Integrate into deploy-apim-basicv2.yml as post-deploy steps

Add the user seeding and OAuth2 setup as optional post-deployment steps.

Files:
* `.github/workflows/deploy-apim-basicv2.yml` — Add post-deploy job

The post-deploy job runs after deploy-dev and deploy-prod, calling the seeding script:
```yaml
post-deploy-dev:
  name: Configure Dev APIM
  needs: deploy-dev
  if: ${{ inputs.deploy_dev }}
  runs-on: ubuntu-latest
  environment: APIM_BasicV2_Dev
  steps:
    - uses: actions/checkout@v4
    - uses: azure/login@v2
      ...
    - name: Seed users and subscriptions
      run: pwsh scripts/seed-apim-users-and-subscriptions.ps1 ...
```

Success criteria:
* Fresh APIM instance has demo users and subscriptions after deployment

Dependencies:
* Steps 2.1, 2.2, 2.3 completion

## Implementation Phase 3: Master Orchestrator Workflow

<!-- parallelizable: false -->

### Step 3.1: Create `create-lab.yml` master workflow

Create a single workflow that provisions the entire lab environment by chaining existing workflows.

Files:
* `.github/workflows/create-lab.yml` — New workflow

The workflow chains:
1. `deploy-apim-basicv2.yml` (reusable workflow call)
2. `deploy-all.yml` (reusable workflow call) — in parallel with APIM
3. Wait for both to complete
4. `run-publisher-006.yaml` steps (inline, since publisher is manual dispatch only)

Inputs:
* `instance_number` (default: 006)
* `location` (default: canadacentral)
* `skip_apis` (default: false) — Skip backend API deployment if only APIM needed

The workflow produces a comprehensive summary with:
* APIM portal URLs (dev + prod)
* All 9 API URLs with version info
* Total deployment time
* Estimated monthly cost

Success criteria:
* Single workflow dispatch creates entire environment
* Total time < 30 minutes
* Summary includes all URLs and status

Dependencies:
* Phase 1 and Phase 2 completion
* Existing workflows must support `workflow_call` trigger

### Step 3.2: Create `teardown-lab.yml` workflow

Create a single teardown workflow with a confirmation gate.

Files:
* `.github/workflows/teardown-lab.yml` — New workflow

The workflow:
1. Lists all resource groups that will be deleted
2. Requires `APIM_Lab_Teardown` environment approval
3. Deletes all 11 resource groups in parallel (async)
4. Writes summary of destroyed resources

Success criteria:
* Single workflow dispatch tears down everything
* Confirmation gate prevents accidental deletion
* All resource groups deleted

### Step 3.3: Add deployment time tracking and cost estimation

Add timing and cost information to the create-lab.yml workflow summary.

Files:
* `.github/workflows/create-lab.yml` — Add timing steps

Each phase records start/end timestamps. Final summary calculates:
* APIM deployment time
* API deployment time
* APIops publish time
* Total wall-clock time
* Estimated monthly cost based on deployed SKUs

Success criteria:
* Deployment times reported in workflow summary
* Cost estimates accurate for BasicV2 + B1 App Service

## Implementation Phase 4: Migration Validation Workflow

<!-- parallelizable: true -->

### Step 4.1: Create `validate-artifacts.yml` pre-publish check

Create a workflow that validates artifact files before publishing to detect v1-specific references.

Files:
* `.github/workflows/validate-artifacts.yml` — New workflow

The workflow:
1. Scans all JSON files in the specified artifact folder
2. Checks for Key Vault references pointing to non-existent vaults
3. Checks for external group references
4. Checks for subscription ownerId references
5. Checks for hardcoded 005 instance names
6. Reports findings as workflow annotations

Success criteria:
* Catches all 8 migration gap categories
* No false positives on clean 006 artifacts
* Clear error messages with file paths

### Step 4.2: Add validation as pre-publish step

Integrate artifact validation into the publisher 006 workflow.

Files:
* `.github/workflows/run-publisher-with-env-006.yaml` — Add validation step

Add a step before the sanitizer that runs validation in report-only mode. Validation failures produce warnings but don't block the publish (sanitizer handles the fixes).

Success criteria:
* Validation runs before every publish
* Warnings visible in workflow summary

Dependencies:
* Step 4.1 completion

## Implementation Phase 5: Validation

<!-- parallelizable: false -->

### Step 5.1: Run full lab create workflow end-to-end

Execute create-lab.yml and verify:
* APIM dev and prod instances created with OAuth2 server and identity provider
* All 9 backend APIs deployed and passing smoke tests
* API configurations published to dev and prod APIM
* Wiki deployment report generated with screenshots
* Demo users and subscriptions seeded

### Step 5.2: Run full tear down

Execute teardown-lab.yml and verify:
* All 11 resource groups deleted
* No orphaned resources remain

### Step 5.3: Report blocking issues

Document any issues found during validation:
* Issues requiring additional research
* Recommendations for Phase 4 (DR, Premium SKU)
* Performance benchmarks for deployment times

## Dependencies

* Azure CLI 2.84+
* APIops v6.0.2
* PowerShell 7.x (pwsh)
* GitHub Actions runners (ubuntu-latest)
* Azure subscription with sufficient quota

## Success Criteria

* Full environment deploys in < 30 minutes via single workflow
* Full teardown completes via single workflow
* Publisher succeeds without manual artifact fixups
* Monthly cost < $40 when using on-demand provisioning (8 hours/week)
