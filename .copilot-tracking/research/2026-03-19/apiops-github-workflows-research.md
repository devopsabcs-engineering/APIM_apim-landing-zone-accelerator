<!-- markdownlint-disable-file -->
# Task Research: APIops GitHub Workflows Migration

Convert 6 Azure DevOps APIops pipelines (3 extractors + 3 publishers) to GitHub Actions workflows, matching the multi-team structure (general, api-team-001, api-team-002).

## Task Implementation Requests

* Create 3 GitHub extractor workflows: general, api-team-001, api-team-002
* Create 3 GitHub publisher workflows: general, api-team-001, api-team-002
* Reuse existing `run-publisher-with-env.yaml` reusable workflow pattern
* Upgrade existing stale workflows (v4.1.2) to latest stable v6.0.2
* Include Spectral linting in extractor workflows
* Support both dev (Dev-005) and prod (Prod-005) APIM environments

## Scope and Success Criteria

* Scope: 6 new/updated GitHub workflows mirroring the 6 ADO pipelines in `tools/azdo_pipelines/`
* Assumptions: GitHub secrets/variables already configured for `dev` environment; federated credentials exist for `gh-apim-deployments` app
* Success Criteria:
  * All 6 workflows can be triggered via `workflow_dispatch`
  * Extractors create PRs with extracted artifacts
  * Publishers deploy artifacts to dev then prod APIM instances
  * Team-specific workflows scope to their respective artifact folders

## Outline

1. Current state analysis (ADO pipelines + existing GitHub workflows)
2. Gap analysis: what's missing
3. Selected approach: upgrade + extend existing GitHub workflows
4. Implementation details per workflow

## Key Discoveries

### Existing GitHub Workflows (already in repo)

Three workflow files already exist at `.github/workflows/`:

| File | Version | Status | Notes |
|------|---------|--------|-------|
| `run-extractor.yaml` | v4.1.2 | Stale, general only | Extracts to `artifacts/` folder, uses old action versions (v2/v3) |
| `run-publisher.yaml` | N/A | Stale, general only | Triggers on PR closed to main, publishes `artifacts/` folder |
| `run-publisher-with-env.yaml` | v4.1.2 | Stale reusable | 4 conditional publisher steps, uses dev/prod environments |

### ADO Pipelines (6 total in `tools/azdo_pipelines/`)

**3 Extractors:**

| Pipeline | Default Artifacts Folder | Config File | Key Difference |
|----------|--------------------------|-------------|----------------|
| `run-extractor.yaml` | `artifacts.dev-005` | Selectable (all 3 configs) | General, all APIs or scoped |
| `run-extractor.api-team-001.yaml` | `artifacts.dev-005.api-team-001` | `configuration.extractor.dev-005.api-team-001.yaml` | Scoped to team 001 APIs |
| `run-extractor.api-team-002.yaml` | `artifacts.dev-005.api-team-002` | `configuration.extractor.dev-005.api-team-002.yaml` | Scoped to team 002 APIs |

**3 Publishers:**

| Pipeline | Default Artifacts Folder | Path Trigger | Key Difference |
|----------|--------------------------|--------------|----------------|
| `run-publisher.yaml` | `artifacts.dev-005` | None (manual) | General, selectable folder |
| `run-publisher.api-team-001.yaml` | `artifacts.dev-005.api-team-001` | `artifacts.dev-005.api-team-001/*` | Auto-triggers on team 001 artifact changes |
| `run-publisher.api-team-002.yaml` | `artifacts.dev-005.api-team-002` | `artifacts.dev-005.api-team-002/*` | Auto-triggers on team 002 artifact changes |

### ADO Variable Group: `APIM_rg-apim-vnet-external-dev-005-eu2-stable`

Contains: `SERVICE_CONNECTION_NAME`, `RESOURCE_GROUP_NAME`, `APIM_NAME`, `RESOURCE_GROUP_NAME_Prod`, `apiops_release_version`

### GitHub Environments Needed

| Environment | Purpose | Secrets/Vars Needed |
|-------------|---------|---------------------|
| `apiops-dev` | Dev APIM (Dev-005) | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP_NAME`, `API_MANAGEMENT_SERVICE_NAME` |
| `apiops-prod` | Prod APIM (Prod-005) | Same set with prod values |

### Authentication

* **ADO**: Uses service connections + `AzureCLI@2` to get bearer token + SPN credentials
* **GitHub (official)**: Uses service principal with client secret via env vars
* **Recommendation**: Use service principal with client secret (same as official approach), stored as GitHub environment secrets

## Technical Scenarios

### Selected Approach: Upgrade Existing + Create Team-Specific Workflows

Upgrade the 3 existing GitHub workflows to v6.0.2 and modern action versions, then create 4 additional team-specific workflows.

**Requirements:**
* 3 extractor workflows (general, team-001, team-002)
* 3 publisher workflows (general, team-001, team-002)
* 1 shared reusable publisher workflow
* All use apiops v6.0.2

**File tree changes:**

```text
.github/workflows/
├── run-extractor.yaml                    (UPDATE: upgrade to v6.0.2, add team folder options)
├── run-extractor.api-team-001.yaml       (NEW: team 001 extractor)
├── run-extractor.api-team-002.yaml       (NEW: team 002 extractor)
├── run-publisher.yaml                    (UPDATE: upgrade, add artifacts.dev-005 folder)
├── run-publisher.api-team-001.yaml       (NEW: team 001 publisher, auto-trigger)
├── run-publisher.api-team-002.yaml       (NEW: team 002 publisher, auto-trigger)
└── run-publisher-with-env.yaml           (UPDATE: upgrade to v6.0.2, modern actions)
```

**Implementation Details:**

1. **Extractor workflows** — manual dispatch only, download extractor v6.0.2 binary, run against dev APIM, include Spectral linting, upload artifact, create PR via `peter-evans/create-pull-request@v6`

2. **Publisher workflows** — team-specific ones auto-trigger on push to main when their artifact folder changes; general is manual. All call `run-publisher-with-env.yaml` reusable workflow for dev then prod stages.

3. **Reusable publisher workflow** — `workflow_call`, handles token substitution, downloads publisher v6.0.2, runs publisher with correct env vars.

4. **Key mappings from ADO → GitHub:**
   - `$(SERVICE_CONNECTION_NAME)` → `azure/login` or direct secret env vars
   - `$(RESOURCE_GROUP_NAME)` → `${{ secrets.AZURE_RESOURCE_GROUP_NAME }}`
   - `$(APIM_NAME)` → `${{ secrets.API_MANAGEMENT_SERVICE_NAME }}`
   - `$(Build.SourcesDirectory)` → `${{ github.workspace }}`
   - `$(Build.ArtifactStagingDirectory)` → `${{ runner.temp }}`
   - `$(apiops_release_version)` → `env.apiops_release_version: v6.0.2`
   - `$(System.AccessToken)` → `${{ secrets.GITHUB_TOKEN }}`
   - `az repos pr create` → `peter-evans/create-pull-request@v6`
   - `replacetokens@6` → `cschleiden/replace-tokens@v1.3`

#### Considered Alternatives

1. **Keep existing v4.1.2 workflows as-is, only add team-specific** — Rejected because v4.1.2 uses deprecated action versions and old binary download patterns. The official repo already uses v6.0.2 with zip-based downloads.

2. **Use OIDC authentication instead of client secret** — Not adopted because the official Azure/apiops tooling expects `AZURE_CLIENT_ID` + `AZURE_CLIENT_SECRET` env vars. OIDC would require modifying the binary invocation pattern, which isn't supported by the apiops extractor/publisher binaries.
