# APIops GitHub Actions Workflows Research

## Research Topics

1. Official GitHub Actions workflow files from `tools/github_workflows` in Azure/apiops
2. Extractor and publisher workflow structure
3. Authentication mechanisms (OIDC vs service principal vs bearer token)
4. Environment variables expected by extractor and publisher binaries
5. How extractor creates PRs in GitHub vs ADO
6. Latest release version/tag

---

## Latest Release Versions

| Channel | Version | Date | Notes |
|---------|---------|------|-------|
| **Latest Stable** | **v6.0.2** | Nov 17, 2025 | Fix PessimisticConcurrencyConflict error codes |
| Latest Pre-release (v7) | v7.0.0-beta.1.0.0 | Jan 28, 2026 | Reverted to camelCase config keys |
| v7 Alpha | v7.0.0-alpha.3.0.1 | Jan 16, 2026 | Logs config values, fixes API spec publishing |

The **latest stable release** is **v6.0.2**. The v7 line is still in beta/pre-release.

---

## Repository Structure: `tools/github_workflows/`

Three files in the directory:

| File | Description |
|------|-------------|
| `run-extractor.yaml` | Extracts APIM artifacts and creates a PR |
| `run-publisher.yaml` | Orchestrates publishing to dev then prod environments |
| `run-publisher-with-env.yaml` | Reusable workflow called by run-publisher for each environment |

---

## Full Content: Official GitHub Extractor Workflow

**File:** `tools/github_workflows/run-extractor.yaml` (182 lines)

```yaml
name: Run - Extractor

on:
  workflow_dispatch:
    inputs:
      CONFIGURATION_YAML_PATH:
        description: 'Choose Wether to extract all Apis or extract apis listed an extraction configuration file'
        required: true
        type: choice
        options:
        - Extract All APIs
        - configuration.extractor.yaml
      API_SPECIFICATION_FORMAT:
        description: 'API Specification Format'
        required: true
        type: choice
        options:
        - OpenAPIV3Yaml
        - OpenAPIV3Json
        - OpenAPIV2Yaml
        - OpenAPIV2Json

env:
  apiops_release_version: desired-version-goes-here

jobs:
  extract:
    runs-on: ubuntu-latest
    environment: dev # change this to match the dev environment created in settings
    steps:
      - uses: actions/checkout@v4

      - name: Run extractor without Config Yaml
        if: ${{ github.event.inputs.CONFIGURATION_YAML_PATH == 'Extract All APIs' }}
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          AZURE_RESOURCE_GROUP_NAME: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
          API_MANAGEMENT_SERVICE_NAME: ${{ secrets.API_MANAGEMENT_SERVICE_NAME }}
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ GITHUB.WORKSPACE }}/apimartifacts  # change this to the artifacts folder
          API_SPECIFICATION_FORMAT: ${{ github.event.inputs.API_SPECIFICATION_FORMAT }}
        run: |
          Set-StrictMode -Version Latest
          $ErrorActionPreference = "Stop"
          $VerbosePreference = "Continue"
          $InformationPreference = "Continue"

          Write-Information "Setting name variables..."
          $releaseFileName = "extractor-linux-x64.zip"
          $executableFileName = "extractor"

          if ("${{ runner.os }}" -like "*win*") {
            $releaseFileName = "extractor-win-x64.zip"
            $executableFileName = "extractor.exe"
          }
          elseif ("${{ runner.os }}" -like "*mac*" -and "${{ runner.arch }}" -like "*arm*") {
            $releaseFileName = "extractor-osx-arm64.zip"
          }
          elseif ("${{ runner.os }}" -like "*mac*" -and "${{ runner.arch }}" -like "*x86_64*") {
            $releaseFileName = "extractor-osx-x64.zip"
          }

          Write-Information "Downloading release..."
          $uri = "https://github.com/Azure/apiops/releases/download/${{ env.apiops_release_version }}/$releaseFileName"
          $downloadFilePath = Join-Path "${{ runner.temp }}" $releaseFileName
          Invoke-WebRequest -Uri "$uri" -OutFile "$downloadFilePath"

          Write-Information "Extracting release..."
          $executableFolderPath = Join-Path "${{ runner.temp }}" "extractor"
          Expand-Archive -Path "$downloadFilePath" -DestinationPath "$executableFolderPath"
          $executableFilePath = Join-Path "$executableFolderPath" $executableFileName

          Write-Information "Setting file permissions..."
          if ("${{ runner.os }}" -like "*linux*")
          {
            & chmod +x "$executableFilePath"
            if ($LASTEXITCODE -ne 0) { throw "Setting file permissions failed."}
          }

          Write-Information "Running extractor..."
          & "$executableFilePath"
          if ($LASTEXITCODE -ne 0) { throw "Running extractor failed."}

          Write-Information "Execution complete."
        shell: pwsh

      - name: Run extractor with Config Yaml
        if: ${{ github.event.inputs.CONFIGURATION_YAML_PATH != 'Extract All APIs' }}
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          AZURE_RESOURCE_GROUP_NAME: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
          API_MANAGEMENT_SERVICE_NAME: ${{ secrets.API_MANAGEMENT_SERVICE_NAME }}
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ GITHUB.WORKSPACE }}/apimartifacts  # change this to the artifacts folder
          API_SPECIFICATION_FORMAT: ${{ github.event.inputs.API_SPECIFICATION_FORMAT }}
          CONFIGURATION_YAML_PATH: ${{ GITHUB.WORKSPACE }}/${{ github.event.inputs.CONFIGURATION_YAML_PATH }}
        run: |
          Set-StrictMode -Version Latest
          $ErrorActionPreference = "Stop"
          $VerbosePreference = "Continue"
          $InformationPreference = "Continue"

          Write-Information "Setting name variables..."
          $releaseFileName = "extractor-linux-x64.zip"
          $executableFileName = "extractor"

          if ("${{ runner.os }}" -like "*win*") {
            $releaseFileName = "extractor-win-x64.zip"
            $executableFileName = "extractor.exe"
          }
          elseif ("${{ runner.os }}" -like "*mac*" -and "${{ runner.arch }}" -like "*arm*") {
            $releaseFileName = "extractor-osx-arm64.zip"
          }
          elseif ("${{ runner.os }}" -like "*mac*" -and "${{ runner.arch }}" -like "*x86_64*") {
            $releaseFileName = "extractor-osx-x64.zip"
          }

          Write-Information "Downloading release..."
          $uri = "https://github.com/Azure/apiops/releases/download/${{ env.apiops_release_version }}/$releaseFileName"
          $downloadFilePath = Join-Path "${{ runner.temp }}" $releaseFileName
          Invoke-WebRequest -Uri "$uri" -OutFile "$downloadFilePath"

          Write-Information "Extracting release..."
          $executableFolderPath = Join-Path "${{ runner.temp }}" "extractor"
          Expand-Archive -Path "$downloadFilePath" -DestinationPath "$executableFolderPath"
          $executableFilePath = Join-Path "$executableFolderPath" $executableFileName

          Write-Information "Setting file permissions..."
          if ("${{ runner.os }}" -like "*linux*")
          {
            & chmod +x "$executableFilePath"
            if ($LASTEXITCODE -ne 0) { throw "Setting file permissions failed."}
          }

          Write-Information "Running extractor..."
          & "$executableFilePath"
          if ($LASTEXITCODE -ne 0) { throw "Running extractor failed."}

          Write-Information "Execution complete."
        shell: pwsh

      - name: publish artifact
        uses: actions/upload-artifact@v4
        env:
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts  # change this to the artifacts folder
        with:
          name: artifacts-from-portal
          path: ${{ GITHUB.WORKSPACE }}/${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}

  create-pull-request:
    needs: extract
    runs-on: [ubuntu-latest]
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Download artifacts-from-portal
        uses: actions/download-artifact@v4
        env:
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts  # change this to the artifacts folder
        with:
          name: artifacts-from-portal
          path: "${{ GITHUB.WORKSPACE }}/${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}"

      - name: Create artifacts pull request
        uses: peter-evans/create-pull-request@v6
        env:
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts  # change this to the artifacts folder
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "updated extract from apim instance ${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}"
          title: "${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }} - extract"
          body: >
            This PR is auto-generated by Github actions workflow
          labels: extract, automated pr
```

---

## Full Content: Official GitHub Publisher Workflow

**File:** `tools/github_workflows/run-publisher.yaml` (70 lines)

```yaml
name: Run - Publisher

on:
  # Triggers the workflow on push events but only for the main branch
  push:
    branches: [main]

  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:
    inputs:
      COMMIT_ID_CHOICE:
        description: 'Choose "publish-all-artifacts-in-repo" only when you want to force republishing all artifacts (e.g. after build failure). Otherwise stick with the default behavior of "publish-artifacts-in-last-commit"'
        required: true
        type: choice
        default: "publish-artifacts-in-last-commit"
        options:
          - "publish-artifacts-in-last-commit"
          - "publish-all-artifacts-in-repo"

jobs:
  get-commit:
    runs-on: ubuntu-latest
    steps:
      # Set the COMMIT_ID env variable
      - name: Set the Commit Id
        id: commit
        run: echo "commit_id=${GITHUB_SHA}" >> $GITHUB_OUTPUT
    outputs:
      commit_id: ${{ steps.commit.outputs.commit_id }}

  #Publish with Commit ID
  Push-Changes-To-APIM-Dev-With-Commit-ID:
    if: (github.event.inputs.COMMIT_ID_CHOICE == 'publish-artifacts-in-last-commit' || github.event.inputs.COMMIT_ID_CHOICE == '')
    needs: get-commit
    uses: ./.github/workflows/run-publisher-with-env.yaml
    with:
      API_MANAGEMENT_ENVIRONMENT: dev # change this to match the dev environment created in settings
      COMMIT_ID: ${{ needs.get-commit.outputs.commit_id }}
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts # change this to the artifacts folder
    secrets: inherit

  #Publish without Commit ID. Publishes all artifacts that reside in the artifacts folder
  Push-Changes-To-APIM-Dev-Without-Commit-ID:
    if: ( github.event.inputs.COMMIT_ID_CHOICE == 'publish-all-artifacts-in-repo' )
    needs: get-commit
    uses: ./.github/workflows/run-publisher-with-env.yaml
    with:
      API_MANAGEMENT_ENVIRONMENT: dev # change this to match the dev environment created in settings
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts # change this to the artifacts folder
    secrets: inherit

  Push-Changes-To-APIM-Prod-With-Commit-ID:
    if: (github.event.inputs.COMMIT_ID_CHOICE == 'publish-artifacts-in-last-commit' || github.event.inputs.COMMIT_ID_CHOICE == '')
    needs: [get-commit, Push-Changes-To-APIM-Dev-With-Commit-ID]
    uses: ./.github/workflows/run-publisher-with-env.yaml
    with:
      API_MANAGEMENT_ENVIRONMENT: prod # change this to match the prod environment created in settings
      CONFIGURATION_YAML_PATH: configuration.prod.yaml # make sure the file is available at the root
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts # change this to the artifacts folder
      COMMIT_ID: ${{ needs.get-commit.outputs.commit_id }}
    secrets: inherit

  Push-Changes-To-APIM-Prod-Without-Commit-ID:
    if: ( github.event.inputs.COMMIT_ID_CHOICE == 'publish-all-artifacts-in-repo' )
    needs: [get-commit, Push-Changes-To-APIM-Dev-Without-Commit-ID]
    uses: ./.github/workflows/run-publisher-with-env.yaml
    with:
      API_MANAGEMENT_ENVIRONMENT: prod # change this to match the prod environment created in settings
      CONFIGURATION_YAML_PATH: configuration.prod.yaml # make sure the file is available at the root
      API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: apimartifacts # change this to the artifacts folder
    secrets: inherit
```

---

## Full Content: Official GitHub Publisher-with-Env Reusable Workflow

**File:** `tools/github_workflows/run-publisher-with-env.yaml`

```yaml
name: Run Publisher with Environment

on:
  workflow_call:
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

env:
  apiops_release_version: desired-version-goes-here
  #By default, this will be Information but if you want something different you will need to add a variable in the Settings -> Environment -> Environment variables section
  Logging__LogLevel__Default: ${{ vars.LOG_LEVEL }}

jobs:
  build:
    runs-on: ubuntu-latest
    environment: ${{ inputs.API_MANAGEMENT_ENVIRONMENT }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      # Run Spectral
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: npm install -g @stoplight/spectral-cli
      - run: spectral lint "${{ GITHUB.WORKSPACE }}/${{ inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}\apis\*.{json,yml,yaml}" --ruleset https://raw.githubusercontent.com/connectedcircuits/devops-api-linter/main/rules.yaml

      # Add this step for each APIM environment and pass specific set of secrets that you want replaced in the env section below
      - name: "Perform namevalue secret substitution in configuration.${{ inputs.API_MANAGEMENT_ENVIRONMENT}}.yaml"
        if: (inputs.API_MANAGEMENT_ENVIRONMENT == 'prod' )
        uses: cschleiden/replace-tokens@v1.3
        with:
          tokenPrefix: "{#"
          tokenSuffix: "#}"
          files: ${{ format('["**/configuration.{0}.yaml"]', inputs.API_MANAGEMENT_ENVIRONMENT) }}
        # specify environment specific secrets to be replaced
        env:
          testSecretValue: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}

      - name: Run publisher without Config Yaml but with Commit ID
        if: ( inputs.CONFIGURATION_YAML_PATH == '' && inputs.COMMIT_ID != '')
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          AZURE_RESOURCE_GROUP_NAME: ${{ secrets.AZURE_RESOURCE_GROUP_NAME }}
          API_MANAGEMENT_SERVICE_NAME: ${{ secrets.API_MANAGEMENT_SERVICE_NAME }}
          API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ GITHUB.WORKSPACE }}/${{ inputs.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}
          COMMIT_ID: ${{ inputs.COMMIT_ID }}
        run: |
          # [download and run publisher binary - same pattern as extractor]
          Set-StrictMode -Version Latest
          $ErrorActionPreference = "Stop"
          $VerbosePreference = "Continue"
          $InformationPreference = "Continue"
          # ... downloads publisher-linux-x64.zip, extracts, chmod +x, runs
          & "$executableFilePath"
          if ($LASTEXITCODE -ne 0) { throw "Running publisher failed."}
        shell: pwsh

      - name: Run publisher without Config Yaml or Commit ID
        if: ( inputs.CONFIGURATION_YAML_PATH == '' && inputs.COMMIT_ID == '')
        # [same auth env vars, runs publisher without COMMIT_ID]

      - name: Run publisher with Config Yaml and Commit id
        if: ( inputs.CONFIGURATION_YAML_PATH != '' && inputs.COMMIT_ID != '')
        env:
          # [same auth env vars plus:]
          CONFIGURATION_YAML_PATH: ${{ GITHUB.WORKSPACE }}/${{ inputs.CONFIGURATION_YAML_PATH }}
          COMMIT_ID: ${{ inputs.COMMIT_ID }}
        # [downloads and runs publisher]

      - name: Run publisher with Config Yaml but without Commit id
        if: ( inputs.CONFIGURATION_YAML_PATH != '' && inputs.COMMIT_ID == '')
        env:
          # [same auth env vars plus:]
          CONFIGURATION_YAML_PATH: ${{ GITHUB.WORKSPACE }}/${{ inputs.CONFIGURATION_YAML_PATH }}
        # [downloads and runs publisher]
```

> **Note:** The reusable workflow has 4 conditional steps covering all combinations of CONFIGURATION_YAML_PATH and COMMIT_ID being set or empty. Each step uses the same download/extract/run pattern. The full binary download logic is identical to the extractor except it downloads `publisher-*.zip` instead of `extractor-*.zip`.

---

## Authentication Mechanisms

### GitHub Actions (Official Approach)

The official GitHub workflows use **service principal with client secret** authentication:

```yaml
env:
  AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

These are passed as **environment variables** to the extractor/publisher binaries. The binaries use `DefaultAzureCredential` internally, which picks up these environment variables as an `EnvironmentCredential`.

### Azure DevOps (Official Approach)

ADO pipelines use a **different two-step approach**:

1. **AzureCLI@2 task** with `addSpnToEnvironment: true` obtains credentials from the ADO Service Connection
2. The task then sets pipeline variables:

```powershell
Write-Host "##vso[task.setvariable issecret=true;variable=AZURE_BEARER_TOKEN]$(az account get-access-token --query "accessToken" --output tsv)"
Write-Host "##vso[task.setvariable issecret=true;variable=AZURE_CLIENT_ID]$env:servicePrincipalId"
Write-Host "##vso[task.setvariable issecret=true;variable=AZURE_CLIENT_SECRET]$env:servicePrincipalKey"
Write-Host "##vso[task.setvariable issecret=true;variable=AZURE_TENANT_ID]$env:tenantId"
```

ADO pipelines pass **both** `AZURE_BEARER_TOKEN` AND `AZURE_CLIENT_ID/SECRET/TENANT_ID`. The GitHub workflows do **not** use `AZURE_BEARER_TOKEN`.

### OIDC / Federated Credentials

The official workflows do **not** use OIDC/federated identity (no `azure/login@v2` with OIDC). They use the traditional client secret approach. However, the binaries support `AZURE_BEARER_TOKEN` as an alternative, which could be obtained via OIDC externally.

### Authentication Priority in the Binaries

Per documentation, the binaries check:

1. `AZURE_BEARER_TOKEN` — if set, uses this directly
2. If not set, uses `DefaultAzureCredential` (which tries EnvironmentCredential with `AZURE_CLIENT_ID`/`AZURE_CLIENT_SECRET`/`AZURE_TENANT_ID`, managed identity, etc.)

---

## Environment Variables Expected by Binaries

### Extractor Binary

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Yes | Subscription ID of the APIM instance |
| `AZURE_RESOURCE_GROUP_NAME` | Yes | Resource group name |
| `API_MANAGEMENT_SERVICE_NAME` | Yes | APIM instance name |
| `API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH` | Yes | Output folder path |
| `AZURE_BEARER_TOKEN` | No | Direct bearer token (bypasses DefaultAzureCredential) |
| `AZURE_CLIENT_ID` | No* | Service principal client ID |
| `AZURE_CLIENT_SECRET` | No* | Service principal client secret |
| `AZURE_TENANT_ID` | No* | Azure AD tenant ID |
| `API_SPECIFICATION_FORMAT` | No | OpenAPI format (OpenAPIV3Yaml, OpenAPIV3Json, OpenAPIV2Yaml, OpenAPIV2Json) |
| `CONFIGURATION_YAML_PATH` | No | Path to extractor config YAML |
| `AZURE_CLOUD_ENVIRONMENT` | No | Cloud environment (AzurePublicCloud, AzureChinaCloud, AzureGermanCloud, AzureUSGovernment) |
| `ARM_API_VERSION` | No | Defaults to 2022-04-01-preview |
| `Logging__LogLevel__Default` | No | Information, Debug, or Trace |
| `APPLICATION_INSIGHTS_CONNECTION_STRING` | No | App Insights connection (v7) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | No | OpenTelemetry endpoint (v7) |
| `DRY_RUN` | No | true/false (v7 publisher, may apply to extractor too) |
| `STRICT_VALIDATION` | No | true/false (v7) |

*Either `AZURE_BEARER_TOKEN` or the client ID/secret/tenant combination is needed.

### Publisher Binary

Same as extractor, plus:

| Variable | Required | Description |
|----------|----------|-------------|
| `COMMIT_ID` | No | Git commit ID for incremental publishing |
| `CONFIGURATION_YAML_PATH` | No | Path to publisher config YAML for environment overrides |

---

## PR Creation: GitHub vs ADO

### GitHub Approach

The extractor workflow uses a **two-job strategy**:

1. **`extract` job**: Runs the extractor binary and uploads artifacts via `actions/upload-artifact@v4`
2. **`create-pull-request` job**: Downloads artifacts and uses the **`peter-evans/create-pull-request@v6`** third-party action

Key GitHub PR details:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write

- uses: peter-evans/create-pull-request@v6
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    commit-message: "updated extract from apim instance ${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}"
    title: "${{ env.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }} - extract"
    body: >
      This PR is auto-generated by Github actions workflow
    labels: extract, automated pr
```

### ADO Approach

ADO uses a **two-stage pipeline** with manual git operations:

1. **`create_artifact_from_portal` stage**: Runs extractor, publishes pipeline artifact
2. **`create_template_branch` stage**: Uses PowerShell scripts to:
   - Clone the repo using `$(System.AccessToken)` bearer header
   - Create a temporary branch `artifacts-from-portal-build-$(Build.BuildId)`
   - Copy artifacts with `rsync`/`robocopy`
   - `git add`, `git commit`, `git push`
   - Create PR using `az repos pr create` CLI command

```powershell
az repos pr create --source-branch "$temporaryBranchName" --target-branch "$branchName" \
  --title "Merging artifacts from portal (Build $(Build.BuildId))" \
  --squash --delete-source-branch "true" --repository "$repositoryName"
```

---

## Key Differences Between ADO and GitHub Approaches

| Aspect | GitHub Actions | Azure DevOps |
|--------|---------------|--------------|
| **Workflow format** | GitHub Actions YAML | ADO Pipeline YAML |
| **PR creation** | `peter-evans/create-pull-request@v6` action | Manual git clone/push + `az repos pr create` CLI |
| **PR permissions** | `permissions: contents/pull-requests/issues: write` | `$(System.AccessToken)` + `AZURE_DEVOPS_EXT_PAT` |
| **Auth to Azure** | Env vars: `AZURE_CLIENT_ID/SECRET/TENANT_ID` from secrets | `AzureCLI@2` with `addSpnToEnvironment: true` → sets bearer token + SP creds |
| **Bearer token** | Not used (relies on DefaultAzureCredential) | Explicitly obtained via `az account get-access-token` |
| **Subscription ID** | Stored as a secret | Auto-detected from service connection (or env var) |
| **Artifact passing** | `actions/upload-artifact@v4` / `actions/download-artifact@v4` | `PublishPipelineArtifact@1` / `DownloadPipelineArtifact@2` |
| **Secret substitution** | `cschleiden/replace-tokens@v1.3` action | `qetza.replacetokens.replacetokens-task.replacetokens@6` task |
| **API linting** | Spectral CLI via npm | Spectral CLI via npm + `PublishTestResults@2` |
| **Reusable workflow** | `workflow_call` with inputs | Template references with `parameters` |
| **Publisher trigger** | `push: branches: [main]` | `trigger: branches: include: [main]` |
| **Extractor trigger** | `workflow_dispatch` only | `trigger: none` (manual parameters) |
| **Environment promotion** | Sequential jobs with `needs` dependency | Stages with deployment jobs and environments |
| **Version pinning** | `apiops_release_version: desired-version-goes-here` (top-level env) | `$(apiops_release_version)` from variable group `apim-automation` |
| **Variable management** | GitHub Secrets per environment | ADO Variable Groups + Pipeline Variables |
| **Binary download** | `Invoke-WebRequest` from GitHub Releases | Same `Invoke-WebRequest` from GitHub Releases |
| **Pipeline summary** | Not implemented | Custom markdown summary via `task.uploadsummary` |

---

## v7 Changes Relevant to Workflows

The v7 branch (pre-release) introduces these changes that affect workflows:

1. **Configuration key names reverted to camelCase** (v7.0.0-beta.1)
2. **Config values logged at startup** (v7.0.0-alpha.3.0.1) — helpful for debugging
3. **Dry-run mode** for publisher (`DRY_RUN` env var or `--dry-run` CLI flag)
4. **Strict validation** (`STRICT_VALIDATION` env var)
5. **Better ID references** — relative references replace absolute subscription/RG IDs
6. **Nested configuration** — configure child resources in YAML
7. **OpenTelemetry support** (`OTEL_EXPORTER_OTLP_ENDPOINT`)

The v7 GitHub workflow files are **identical** to the main branch workflow files — no workflow-level changes in v7.

---

## Binary Download Pattern

Both GitHub and ADO workflows follow the same pattern:

1. Determine OS/architecture-specific release zip filename
2. Download from `https://github.com/Azure/apiops/releases/download/{version}/{filename}`
3. Extract the zip
4. Set execute permissions on Linux
5. Run the binary (all config is via environment variables)

Available binaries per platform:

- `extractor-linux-x64.zip` / `publisher-linux-x64.zip`
- `extractor-linux-arm64.zip` / `publisher-linux-arm64.zip`
- `extractor-linux-musl-x64.zip` / `publisher-linux-musl-x64.zip`
- `extractor-linux-musl-arm64.zip` / `publisher-linux-musl-arm64.zip`
- `extractor-win-x64.zip` / `publisher-win-x64.zip`
- `extractor-osx-arm64.zip` / `publisher-osx-arm64.zip`
- `extractor-osx-x64.zip` / `publisher-osx-x64.zip`

---

## References

- Extractor workflow: https://github.com/Azure/apiops/blob/main/tools/github_workflows/run-extractor.yaml
- Publisher workflow: https://github.com/Azure/apiops/blob/main/tools/github_workflows/run-publisher.yaml
- Publisher-with-env workflow: https://github.com/Azure/apiops/blob/main/tools/github_workflows/run-publisher-with-env.yaml
- ADO extractor pipeline: https://github.com/Azure/apiops/blob/main/tools/azdo_pipelines/run-extractor.yaml
- ADO publisher pipeline: https://github.com/Azure/apiops/blob/main/tools/azdo_pipelines/run-publisher.yaml
- ADO publisher-with-env: https://github.com/Azure/apiops/blob/main/tools/azdo_pipelines/run-publisher-with-env.yaml
- Extractor docs: https://github.com/Azure/apiops/blob/main/docs/apiops/3-apimTools/apiops-2-1-tools-extractor.md
- Publisher docs: https://github.com/Azure/apiops/blob/main/docs/apiops/3-apimTools/apiops-2-2-tools-publisher.md
- Releases: https://github.com/Azure/apiops/releases
- Latest stable: https://github.com/Azure/apiops/releases/tag/v6.0.2
- Latest pre-release: https://github.com/Azure/apiops/releases/tag/v7.0.0-beta.1.0.0
