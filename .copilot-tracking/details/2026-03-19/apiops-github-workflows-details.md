<!-- markdownlint-disable-file -->
# Implementation Details: APIops GitHub Workflows Migration

## Context Reference

Sources: `.copilot-tracking/research/2026-03-19/apiops-github-workflows-research.md`, existing GitHub workflows in `.github/workflows/`, ADO pipelines in `tools/azdo_pipelines/`

## Implementation Phase 1: Upgrade Existing Reusable Publisher Workflow

<!-- parallelizable: false -->

### Step 1.1: Upgrade `run-publisher-with-env.yaml` to v6.0.2

Rewrite the reusable publisher workflow to use apiops v6.0.2 zip-based download pattern, modern action versions, and updated token replacement. This workflow is called by all 3 publisher workflows.

**Key changes from current:**
- `apiops_release_version: v4.1.2` → `apiops_release_version: v6.0.2`
- `actions/setup-node@v3` → `actions/setup-node@v4` with `node-version: "20"`
- `actions/checkout@v3` → `actions/checkout@v4`
- `cschleiden/replace-tokens@v1.1` → `cschleiden/replace-tokens@v1.3`
- Download pattern: bare executable → zip download + `Expand-Archive`
- Spectral lint: remove from publisher (move to extractors only)
- 4 conditional publisher run steps remain (with/without config YAML, with/without commit ID)

**Updated workflow_call inputs (unchanged):**
```yaml
inputs:
  API_MANAGEMENT_ENVIRONMENT:
    required: true
    type: string
  CONFIGURATION_YAML_PATH:
    required: false
    type: string
  COMMIT_ID:
    required: false
    type: string
  API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH:
    required: true
    type: string
```

**Updated env block:**
```yaml
env:
  apiops_release_version: v6.0.2
  Logging__LogLevel__Default: Debug
```

**Updated checkout step:**
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 2
```

**Updated token replacement step:**
```yaml
- name: "Perform namevalue secret substitution in configuration.prod-005.yaml"
  if: (inputs.API_MANAGEMENT_ENVIRONMENT == 'prod' )
  uses: cschleiden/replace-tokens@v1.3
  with:
    tokenPrefix: "{#"
    tokenSuffix: "#}"
    files: '["**/configuration.prod-005.yaml"]'
  env:
    testSecretValue: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
```

> **Note:** The file pattern is hardcoded to `configuration.prod-005.yaml` instead of using the dynamic `format()` function because the actual prod config file uses the `-005` suffix which doesn't match the environment name `prod`.

**Updated publisher download pattern (replace all 4 publisher run steps):**
Each of the 4 conditional steps changes the download section from:
```powershell
$publisherFileName = "${{ runner.os }}" -like "*win*" ? "publisher.win-x64.exe" : "publisher.linux-x64.exe"
$uri = "https://github.com/Azure/apiops/releases/download/${{ env.apiops_release_version }}/$publisherFileName"
$destinationFilePath = Join-Path "${{ runner.temp }}" "publisher.exe"
Invoke-WebRequest -Uri "$uri" -OutFile "$destinationFilePath"
```
To:
```powershell
$releaseFileName = "publisher-linux-x64.zip"
$executableFileName = "publisher"
if ("${{ runner.os }}" -like "*win*") {
  $releaseFileName = "publisher-win-x64.zip"
  $executableFileName = "publisher.exe"
}
$uri = "https://github.com/Azure/apiops/releases/download/${{ env.apiops_release_version }}/$releaseFileName"
$downloadFilePath = Join-Path "${{ runner.temp }}" $releaseFileName
Invoke-WebRequest -Uri "$uri" -OutFile "$downloadFilePath"
$executableFolderPath = Join-Path "${{ runner.temp }}" "publisher"
Expand-Archive -Path "$downloadFilePath" -DestinationPath "$executableFolderPath"
$destinationFilePath = Join-Path "$executableFolderPath" $executableFileName
```

**Remove Spectral lint section** that currently exists at the top of the reusable workflow (lines using `setup-node` and `spectral lint`). Spectral linting moves to extractor workflows.

Files:
* `.github/workflows/run-publisher-with-env.yaml` - UPDATE: full rewrite with v6.0.2 pattern

Discrepancy references:
* Addresses research requirement for v6.0.2 upgrade and zip download pattern

Success criteria:
* File parses as valid GitHub Actions YAML
* `workflow_call` inputs unchanged so existing callers still work
* Version is v6.0.2
* Download uses zip + `Expand-Archive` pattern
* Token replacement uses `@v1.3`
* No Spectral lint steps remain

Dependencies:
* None (foundation workflow, must be upgraded first)

## Implementation Phase 2: Upgrade and Extend Extractor Workflows

<!-- parallelizable: true -->

### Step 2.1: Upgrade `run-extractor.yaml` (general extractor)

Full rewrite of the existing general extractor to match ADO `tools/azdo_pipelines/run-extractor.yaml` capabilities.

**Key changes:**
- Version: v4.1.2 → v6.0.2
- Output folder: `artifacts` → selectable (`artifacts.dev-005`, `artifacts.dev-005.api-team-001`, `artifacts.dev-005.api-team-002`)
- Config file: selectable (`Extract All APIs`, `configuration.extractor.dev-005.yaml`, `configuration.extractor.dev-005.api-team-001.yaml`, `configuration.extractor.dev-005.api-team-002.yaml`)
- Download: bare exe → zip + `Expand-Archive`
- Actions: v2/v3 → v4
- Add: Spectral linting step after extraction
- Add: PR creation via `peter-evans/create-pull-request@v6`
- Environment: `dev` → `dev` (keep as `dev` to match reusable workflow conditional logic)

**Updated workflow_dispatch inputs:**
```yaml
on:
  workflow_dispatch:
    inputs:
      CONFIGURATION_YAML_PATH:
        description: 'Choose whether to extract all APIs or use a configuration file'
        required: true
        type: choice
        options:
          - Extract All APIs
          - configuration.extractor.yaml
          - configuration.extractor.dev-005.yaml
          - configuration.extractor.dev-005.api-team-001.yaml
          - configuration.extractor.dev-005.api-team-002.yaml
      API_SPECIFICATION_FORMAT:
        description: 'API Specification Format'
        required: true
        type: choice
        options:
          - OpenAPIV3Yaml
          - OpenAPIV3Json
          - OpenAPIV2Yaml
          - OpenAPIV2Json
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH:
        description: 'Folder where you want to extract the artifacts'
        required: true
        type: choice
        default: 'artifacts.dev-005'
        options:
          - artifacts
          - artifacts.dev-005
          - artifacts.dev-005.api-team-001
          - artifacts.dev-005.api-team-002
```

**Extraction job structure:**
1. `actions/checkout@v4`
2. Download extractor v6.0.2 zip, extract, set permissions
3. Run extractor (two conditional steps: with/without config YAML)
4. Install Node.js via `actions/setup-node@v4` with `node-version: "20"`
5. Install Spectral: `npm install -g @stoplight/spectral-cli`
6. Run Spectral lint on extracted specifications (continue-on-error)
7. Upload artifact via `actions/upload-artifact@v4`
8. Create PR via `peter-evans/create-pull-request@v6`

**Spectral lint step:**
```yaml
- name: Run Spectral Linting
  run: |
    spectral lint "${{ github.workspace }}/${{ github.event.inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}/apis/**/specification.{json,yaml,yml}" \
      -r https://raw.githubusercontent.com/connectedcircuits/devops-api-linter/main/rules.yaml \
      --format stylish || true
  shell: bash
  continue-on-error: true
```

**PR creation step:**
```yaml
- name: Create pull request
  uses: peter-evans/create-pull-request@v6
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    commit-message: "Update ${{ github.event.inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }} artifacts from APIM"
    title: "Update APIM artifacts - ${{ github.event.inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}"
    body: "Automated extraction of APIM artifacts from dev environment"
    branch: "artifacts-from-portal-${{ github.run_id }}"
    base: main
    add-paths: |
      ${{ github.event.inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}/**
```

Files:
* `.github/workflows/run-extractor.yaml` - UPDATE: full rewrite

Discrepancy references:
* Mirrors ADO `tools/azdo_pipelines/run-extractor.yaml` capabilities

Success criteria:
* Supports 4 config file options + Extract All (including backward-compatible `configuration.extractor.yaml`)
* Supports 4 output folder options (including backward-compatible `artifacts`)
* Downloads v6.0.2 zip extractor
* Includes Spectral lint step
* Creates PR via `peter-evans/create-pull-request@v6`
* Uses `dev` environment

Context references:
* `tools/azdo_pipelines/run-extractor.yaml` (Lines 1-300) - ADO source pipeline
* `.github/workflows/run-extractor.yaml` (Lines 1-120) - Current GitHub workflow

Dependencies:
* None (independent of Phase 1)

### Step 2.2: Create `run-extractor.api-team-001.yaml`

New workflow scoped to team-001 artifacts. Simpler than general extractor — fixed config file and output folder.

**Key characteristics:**
- Fixed output folder: `artifacts.dev-005.api-team-001`
- Fixed config file: `configuration.extractor.dev-005.api-team-001.yaml`
- Manual trigger only (`workflow_dispatch`)
- Same extraction + Spectral + PR pattern as general extractor
- Environment: `apiops-dev`

**Workflow dispatch inputs:**
```yaml
on:
  workflow_dispatch:
    inputs:
      API_SPECIFICATION_FORMAT:
        description: 'API Specification Format'
        required: true
        type: choice
        options:
          - OpenAPIV3Yaml
          - OpenAPIV3Json
          - OpenAPIV2Yaml
          - OpenAPIV2Json
```

**Hardcoded values:**
- `API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ github.workspace }}/artifacts.dev-005.api-team-001`
- `CONFIGURATION_YAML_PATH: ${{ github.workspace }}/configuration.extractor.dev-005.api-team-001.yaml`

**PR creation branch:** `artifacts-from-portal-team-001-${{ github.run_id }}`

Files:
* `.github/workflows/run-extractor.api-team-001.yaml` - NEW

Success criteria:
* Scoped to `artifacts.dev-005.api-team-001` folder only
* Uses `configuration.extractor.dev-005.api-team-001.yaml` config
* Includes Spectral lint and PR creation
* Uses v6.0.2 zip download

Context references:
* `tools/azdo_pipelines/run-extractor.api-team-001.yaml` (Lines 1-150) - ADO source pipeline

Dependencies:
* None (independent)

### Step 2.3: Create `run-extractor.api-team-002.yaml`

New workflow scoped to team-002 artifacts. Identical structure to team-001 with different folder/config paths.

**Key characteristics:**
- Fixed output folder: `artifacts.dev-005.api-team-002`
- Fixed config file: `configuration.extractor.dev-005.api-team-002.yaml`
- Manual trigger only (`workflow_dispatch`)
- Environment: `apiops-dev`

**Hardcoded values:**
- `API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ github.workspace }}/artifacts.dev-005.api-team-002`
- `CONFIGURATION_YAML_PATH: ${{ github.workspace }}/configuration.extractor.dev-005.api-team-002.yaml`

**PR creation branch:** `artifacts-from-portal-team-002-${{ github.run_id }}`

Files:
* `.github/workflows/run-extractor.api-team-002.yaml` - NEW

Success criteria:
* Scoped to `artifacts.dev-005.api-team-002` folder only
* Uses `configuration.extractor.dev-005.api-team-002.yaml` config
* Includes Spectral lint and PR creation
* Uses v6.0.2 zip download
* Uses `dev` environment* Uses `dev` environment
Context references:
* `tools/azdo_pipelines/run-extractor.api-team-002.yaml` (Lines 1-150) - ADO source pipeline

Dependencies:
* None (independent)

## Implementation Phase 3: Upgrade and Extend Publisher Workflows

<!-- parallelizable: true -->

### Step 3.1: Upgrade `run-publisher.yaml` (general publisher)

Rewrite existing general publisher to match ADO `tools/azdo_pipelines/run-publisher.yaml` multi-folder support and dev→prod staging.

**Key changes:**
- Default artifact folder: `artifacts` → `artifacts.dev-005`
- Add folder options: `artifacts.dev-005`, `artifacts.dev-005.api-team-001`, `artifacts.dev-005.api-team-002`
- Dev environment: `dev` → `dev` (unchanged to preserve reusable workflow conditionals)
- Prod environment: (new) `prod`
- Prod configuration: `configuration.prod.yaml` → `configuration.prod-005.yaml`
- Keep PR close trigger + manual dispatch

**Updated triggers and inputs:**
```yaml
on:
  pull_request:
    branches: [main]
    types: [closed]
  workflow_dispatch:
    inputs:
      COMMIT_ID_CHOICE:
        description: 'Choose publish mode'
        required: true
        type: choice
        default: "publish-artifacts-in-last-commit"
        options:
          - "publish-artifacts-in-last-commit"
          - "publish-all-artifacts-in-repo"
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH:
        description: 'Artifacts folder'
        required: true
        type: choice
        default: "artifacts.dev-005"
        options:
          - "artifacts"
          - "artifacts.dev-005"
          - "artifacts.dev-005.api-team-001"
          - "artifacts.dev-005.api-team-002"
```

**Job structure (4 jobs, same pattern as current but updated):**
1. `get-commit` — resolve commit SHA
2. `Push-Changes-To-APIM-Dev-With-Commit-ID` — calls reusable workflow with `dev` environment
3. `Push-Changes-To-APIM-Dev-Without-Commit-ID` — calls reusable workflow with `dev` environment
4. `Push-Changes-To-APIM-Prod-With-Commit-ID` — calls reusable workflow with `prod` environment, `configuration.prod-005.yaml`
5. `Push-Changes-To-APIM-Prod-Without-Commit-ID` — calls reusable workflow with `prod` environment, `configuration.prod-005.yaml`

**Updated reusable workflow calls use dynamic folder:**
```yaml
with:
  API_MANAGEMENT_ENVIRONMENT: dev
  COMMIT_ID: ${{ needs.get-commit.outputs.commit_id }}
  API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ github.event.inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH || 'artifacts.dev-005' }}
```

Files:
* `.github/workflows/run-publisher.yaml` - UPDATE: rewrite with multi-folder support

Discrepancy references:
* DD-01: Environment names differ from ADO (GitHub uses `apiops-dev`/`apiops-prod` vs ADO `Dev-005-stable`/`APIM_rg-apim-...`)

Success criteria:
* Supports 4 artifact folder options via `workflow_dispatch` (including backward-compatible `artifacts`)
* Triggers on PR close to main (backward compatible)
* Calls `run-publisher-with-env.yaml` for dev then prod stages
* Uses `configuration.prod-005.yaml` for prod stage
* Uses `dev`/`prod` environment names to match reusable workflow conditionals

Context references:
* `tools/azdo_pipelines/run-publisher.yaml` (Lines 1-100) - ADO source pipeline
* `.github/workflows/run-publisher.yaml` (Lines 1-70) - Current GitHub workflow

Dependencies:
* Phase 1 (reusable workflow must be upgraded first)

### Step 3.2: Create `run-publisher.api-team-001.yaml`

New team-001 publisher with auto-trigger on push to main when team-001 artifacts change.

**Key characteristics:**
- Auto-trigger: push to `main` with path filter `artifacts.dev-005.api-team-001/**`
- Manual trigger: `workflow_dispatch` with commit ID choice
- Fixed artifact folder: `artifacts.dev-005.api-team-001`
- Dev → Prod staging via reusable workflow
- Prod config: `configuration.prod-005.yaml`

**Triggers:**
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'artifacts.dev-005.api-team-001/**'
  workflow_dispatch:
    inputs:
      COMMIT_ID_CHOICE:
        description: 'Choose publish mode'
        required: true
        type: choice
        default: "publish-artifacts-in-last-commit"
        options:
          - "publish-artifacts-in-last-commit"
          - "publish-all-artifacts-in-repo"
```

**Job structure:** Same 5-job pattern as general publisher but with fixed folder `artifacts.dev-005.api-team-001`.

Files:
* `.github/workflows/run-publisher.api-team-001.yaml` - NEW

Discrepancy references:
* Mirrors ADO `tools/azdo_pipelines/run-publisher.api-team-001.yaml` path trigger

Success criteria:
* Auto-triggers on push to main with `artifacts.dev-005.api-team-001/**` path changes
* Supports manual dispatch
* Fixed to `artifacts.dev-005.api-team-001` folder
* Calls reusable workflow for dev then prod

Context references:
* `tools/azdo_pipelines/run-publisher.api-team-001.yaml` (Lines 1-100) - ADO source pipeline

Dependencies:
* Phase 1 (reusable workflow must be upgraded first)

### Step 3.3: Create `run-publisher.api-team-002.yaml`

New team-002 publisher with auto-trigger. Identical structure to team-001 with different path filter and folder.

**Key characteristics:**
- Auto-trigger: push to `main` with path filter `artifacts.dev-005.api-team-002/**`
- Fixed artifact folder: `artifacts.dev-005.api-team-002`
- Dev → Prod staging via reusable workflow

Files:
* `.github/workflows/run-publisher.api-team-002.yaml` - NEW

Success criteria:
* Auto-triggers on push to main with `artifacts.dev-005.api-team-002/**` path changes
* Supports manual dispatch
* Fixed to `artifacts.dev-005.api-team-002` folder
* Calls reusable workflow for dev then prod

Context references:
* `tools/azdo_pipelines/run-publisher.api-team-002.yaml` (Lines 1-100) - ADO source pipeline

Dependencies:
* Phase 1 (reusable workflow must be upgraded first)

## Implementation Phase 4: Validation

<!-- parallelizable: false -->

### Step 4.1: Validate all 7 workflow YAML files syntax

Verify all workflow files parse as valid GitHub Actions YAML:
* `.github/workflows/run-publisher-with-env.yaml`
* `.github/workflows/run-extractor.yaml`
* `.github/workflows/run-extractor.api-team-001.yaml`
* `.github/workflows/run-extractor.api-team-002.yaml`
* `.github/workflows/run-publisher.yaml`
* `.github/workflows/run-publisher.api-team-001.yaml`
* `.github/workflows/run-publisher.api-team-002.yaml`

### Step 4.2: Verify cross-workflow references

Confirm all publisher workflows correctly reference `run-publisher-with-env.yaml` via `uses: ./.github/workflows/run-publisher-with-env.yaml`. Verify `workflow_call` input names match between caller and callee.

### Step 4.3: Verify artifact folder and config path consistency

| Extractor Workflow | Output Folder | Config File |
|-|-|-|
| `run-extractor.yaml` | `artifacts.dev-005` (default) | Selectable |
| `run-extractor.api-team-001.yaml` | `artifacts.dev-005.api-team-001` | `configuration.extractor.dev-005.api-team-001.yaml` |
| `run-extractor.api-team-002.yaml` | `artifacts.dev-005.api-team-002` | `configuration.extractor.dev-005.api-team-002.yaml` |

| Publisher Workflow | Input Folder | Path Trigger |
|-|-|-|
| `run-publisher.yaml` | `artifacts.dev-005` (default) | PR close to main |
| `run-publisher.api-team-001.yaml` | `artifacts.dev-005.api-team-001` | `artifacts.dev-005.api-team-001/**` |
| `run-publisher.api-team-002.yaml` | `artifacts.dev-005.api-team-002` | `artifacts.dev-005.api-team-002/**` |

### Step 4.4: Document blocking issues

When validation failures or environment-dependent issues arise:
* Document GitHub environment/secret prerequisites
* Provide the user with next steps for runtime testing
* Note any issues requiring manual GitHub settings configuration

## Dependencies

* apiops v6.0.2 release on GitHub (`Azure/apiops` releases)
* `peter-evans/create-pull-request@v6` GitHub Action
* `cschleiden/replace-tokens@v1.3` GitHub Action
* `actions/checkout@v4`, `actions/upload-artifact@v4`, `actions/setup-node@v4`
* `@stoplight/spectral-cli` npm package
* GitHub environments `apiops-dev` and `apiops-prod` with secrets configured

## Success Criteria

* All 7 workflow files are valid GitHub Actions YAML
* Version v6.0.2 used consistently across all workflows
* Extractor→Publisher folder paths align for all 3 team scopes
* ADO pipeline feature parity achieved for all 6 pipeline equivalents
