<!-- markdownlint-disable-file -->
# Task Research: Architecture Diagrams from Bicep for GitHub Wiki

Continuously generate architecture diagrams with official Azure icons from Bicep infrastructure-as-code files for each of the 9 API/app backends and the APIM Basic v2 deployment, publishing only the latest version to the GitHub Wiki — following the same pattern used for deployment screenshots.

## Task Implementation Requests

* Automatically generate architecture diagrams from `main.bicep` files (source of truth) for all 10 deployments (9 backends + APIM)
* Use official-style Azure icons for professional, recognizable diagrams
* Run continuously in CI/CD (GitHub Actions) on every deployment or Bicep change
* Publish only the latest version to the GitHub Wiki (overwrite previous)
* Follow the existing screenshot-to-wiki pattern already established in `deploy-all.yml`

## Scope and Success Criteria

* Scope: All 5 active Bicep templates covering 10 deployment targets (6 apps sharing `infra/appservice/main.bicep`, plus 4 unique templates). Excludes `infra/webapp/main.bicep` (unused) and `reference-implementations/` (separate architecture).
* Assumptions:
  * GitHub Wiki is already initialized (existing deployment report workflow confirms this)
  * `GITHUB_TOKEN` has `contents: write` permission (already configured in existing workflows)
  * Diagrams represent resources defined in Bicep, not live Azure state
  * One diagram per deployment target (10 diagrams total)
* Success Criteria:
  * Each of the 10 deployments has an architecture diagram with Azure icons
  * Diagrams auto-generate from `main.bicep` files via `bicep build` → ARM JSON → diagram
  * Wiki pages display the latest diagrams, overwriting previous versions
  * Workflow integrates into the existing `deploy-all.yml` or `create-lab.yml` pipeline
  * Diagrams update when Bicep files change

## Outline

1. Bicep file inventory and resource mapping
2. Tool evaluation and selection
3. Implementation approach: Bicep → ARM JSON → Python `diagrams`
4. GitHub Wiki publishing integration
5. Workflow placement and trigger strategy
6. Complete examples (generate_diagram.py, workflow YAML)
7. Considered alternatives

## Research Executed

### File Analysis

* [infra/appservice/main.bicep](infra/appservice/main.bicep) — 5-8 resources: App Service Plan, App Service (container), ACR, Log Analytics, App Insights, optional Storage. Used by 6 apps (Weather, Star Wars, SOAP, OData, Movie, Web App).
* [infra/fnapp/main.bicep](infra/fnapp/main.bicep) — ~24 resources: VNet, 4× Private DNS Zones, 4× DNS Links, Storage (private), 4× Private Endpoints, ACR, UAMI, Function App, App Service Plan, App Insights, Log Analytics, 12 RBAC role assignments. Most complex template. Used by Appointments API.
* [infra/api-management-basicv2/main.bicep](infra/api-management-basicv2/main.bicep) — 7-8 resources: APIM service (BasicV2), Log Analytics, App Insights, Key Vault, RBAC, Named Value, Logger, optional OAuth2 server. Used for Dev + Prod APIM.
* [src/fast-api-app-insights/main.bicep](src/fast-api-app-insights/main.bicep) — 3 resources: App Service Plan, App Insights, App Service (Python/uvicorn). Simplest template.
* [src/msal-python-soln/python-flask-webapp/main.bicep](src/msal-python-soln/python-flask-webapp/main.bicep) — 6 resources: App Insights, App Service, App Service Plan, Key Vault, Secret, RBAC.
* [infra/webapp/main.bicep](infra/webapp/main.bicep) — 4 resources. **Not used by any current workflow.** Legacy/inactive.

### Code Search Results

* `screenshot` — Found Puppeteer-based screenshot capture in 8 of 9 deploy workflows (all except `deploy-appointments-api.yml`)
* `publish-wiki` — Found in `deploy-all.yml` (lines 164-355): downloads screenshot artifacts, builds Markdown report, clones wiki, pushes images and report
* `mermaid` — **No results.** No Mermaid diagrams in the repository.
* `diagrams` — Only `docs/assets/diagrams/` folder with Draw.io/Visio/PNG/SVG assets
* `bicep visualize` — No results. No automated diagram generation exists.

### Project Conventions

* **Screenshot artifacts:** Named `screenshot-{app-name}`, uploaded with 30-day retention
* **Wiki images:** Stored at wiki repo root (GitHub Wiki limitation), referenced with relative paths
* **Overwrite strategy:** `rm -f` old files → write new → `git add -A` → push (latest only, Git history preserves old)
* **Wiki auth:** `GITHUB_TOKEN` via `x-access-token` clone URL, tries `master` then `main`
* **Existing diagram formats:** Visio (.vsdx), Draw.io (.drawio), SVG, PNG — no text-based diagram-as-code

## Key Discoveries

### Bicep-to-Deployment Mapping (Source of Truth)

| Workflow | App | Bicep Template | Resource Group |
|---|---|---|---|
| `deploy-weather-api.yml` | Weather API | `infra/appservice/main.bicep` | `rg-weather-appservice-linux-{instance}` |
| `deploy-star-wars-api.yml` | Star Wars API | `infra/appservice/main.bicep` | `rg-star-wars-appservice-linux-{instance}` |
| `deploy-soap-api.yml` | SOAP API | `infra/appservice/main.bicep` | `rg-soap-appservice-linux-{instance}` |
| `deploy-odata-api.yml` | OData API | `infra/appservice/main.bicep` | `rg-odata-appservice-linux-{instance}` |
| `deploy-movie-api.yml` | Movie API | `infra/appservice/main.bicep` | `rg-movies-appservice-linux-{instance}` |
| `deploy-web-app.yml` | Web App | `infra/appservice/main.bicep` | `rg-web-appservice-linux-{instance}` |
| `deploy-flask-app.yml` | Flask App | `src/msal-python-soln/python-flask-webapp/main.bicep` | `rg-msal-python-soln` |
| `deploy-fast-api.yml` | Fast API | `src/fast-api-app-insights/main.bicep` | `rg-fast-api-app-insights-001` |
| `deploy-appointments-api.yml` | Appointments API | `infra/fnapp/main.bicep` | `rg-appointments-fnapp-linux-{instance}` |
| `deploy-apim-basicv2.yml` | APIM (Dev+Prod) | `infra/api-management-basicv2/main.bicep` | `rg-apim-basicv2-{env}-{instance}` |

### Total Resource Inventory (~93 Azure resources)

| Template | Apps | Resources Per Deploy | Total |
|---|---|---|---|
| `infra/appservice/main.bicep` | 6 apps | 5-8 | ~36-48 |
| `infra/fnapp/main.bicep` | 1 app | ~24 | ~24 |
| `infra/api-management-basicv2/main.bicep` | 2 envs | 7-8 | ~16 |
| `src/fast-api-app-insights/main.bicep` | 1 app | 3 | ~3 |
| `src/msal-python-soln/python-flask-webapp/main.bicep` | 1 app | 6 | ~6 |

### No Shared Bicep Modules

All 5 active templates are fully self-contained — no external module references. Each defines all resources inline. This simplifies diagram generation: each `main.bicep` can be processed independently.

### Existing Wiki Publishing Pattern (Proven)

The `deploy-all.yml` `publish-wiki` job provides an established, working pattern:

1. Download artifacts → 2. Build Markdown report → 3. Clone wiki repo → 4. Delete old files → 5. Copy new files to wiki root → 6. Commit and push

Key technical details:
* Clone: `git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"`
* Images **must** be at wiki repo root (GitHub Wiki limitation)
* Push tries `master` then `main` branch
* Permissions: `contents: write` (already set in `create-lab.yml`)

### ARM Resource Type → `diagrams` Node Mapping

| ARM Resource Type | `diagrams` Module | Node Class |
|---|---|---|
| `Microsoft.ApiManagement/service` | `azure.integration` | `APIManagement` |
| `Microsoft.Web/serverfarms` | `azure.web` | `AppServicePlans` |
| `Microsoft.Web/sites` | `azure.web` | `AppServices` |
| `Microsoft.Web/sites` (Function) | `azure.compute` | `FunctionApps` |
| `Microsoft.Insights/components` | `azure.devops` | `ApplicationInsights` |
| `Microsoft.OperationalInsights/workspaces` | `azure.devops` | `ApplicationInsights` |
| `Microsoft.ContainerRegistry/registries` | `azure.compute` | `ContainerRegistries` |
| `Microsoft.KeyVault/vaults` | `azure.security` | `KeyVaults` |
| `Microsoft.Storage/storageAccounts` | `azure.storage` | `StorageAccounts` |
| `Microsoft.Network/virtualNetworks` | `azure.network` | `VirtualNetworks` |
| `Microsoft.Network/privateDnsZones` | `azure.network` | `DNSZones` |
| `Microsoft.Network/privateEndpoints` | `azure.network` | `PrivateEndpoint` |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `azure.identity` | `ManagedIdentities` |
| `Microsoft.Authorization/roleAssignments` | `azure.identity` | `ActiveDirectory` |

## Technical Scenarios

### Scenario: Automated Architecture Diagram Generation from Bicep

Generate 10 architecture diagrams (one per deployment target) from `main.bicep` files using Python `diagrams` library with official Azure icons, triggered on Bicep changes or deployment, publishing the latest version to GitHub Wiki.

**Requirements:**

* Parse Bicep → ARM JSON programmatically in CI/CD
* Map ARM resource types to Azure icon nodes
* Generate professional diagrams with resource group clusters
* Publish to GitHub Wiki using existing pattern
* Only keep latest version (overwrite)
* Run headlessly in GitHub Actions (Ubuntu runner)

**Preferred Approach: Python `diagrams` library + Custom Bicep Parser**

The Python `diagrams` library (42.1k GitHub stars, official Azure icons updated to v18) is the clear winner. The pipeline:

```text
main.bicep → bicep build → ARM JSON → Python parser → diagrams library → PNG → Wiki push
```

```text
File changes needed:
├── scripts/
│   └── generate_architecture_diagrams.py   ← NEW: Parse ARM JSON, generate diagrams
├── .github/workflows/
│   ├── generate-architecture-diagrams.yml  ← NEW: Standalone workflow (on Bicep changes)
│   └── deploy-all.yml                      ← MODIFY: Add diagram generation to publish-wiki job
```

```mermaid
graph LR
    A[main.bicep] -->|bicep build| B[main.json ARM]
    B -->|Python parser| C[Resource graph]
    C -->|diagrams library| D[PNG diagram]
    D -->|git push| E[GitHub Wiki]
```

**Implementation Details:**

**Step 1: Install dependencies in GitHub Actions**

```yaml
- name: Install diagram dependencies
  run: |
    curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
    chmod +x bicep && sudo mv bicep /usr/local/bin/
    sudo apt-get install -y graphviz
    pip install diagrams
```

**Step 2: Build ARM JSON from all Bicep files**

```yaml
- name: Build ARM JSON from Bicep
  run: |
    bicep build infra/appservice/main.bicep --outfile /tmp/appservice.json
    bicep build infra/fnapp/main.bicep --outfile /tmp/fnapp.json
    bicep build infra/api-management-basicv2/main.bicep --outfile /tmp/apim.json
    bicep build src/fast-api-app-insights/main.bicep --outfile /tmp/fastapi.json
    bicep build src/msal-python-soln/python-flask-webapp/main.bicep --outfile /tmp/flask.json
```

**Step 3: Python diagram generator script (core logic)**

```python
#!/usr/bin/env python3
"""Generate Azure architecture diagrams from ARM JSON (compiled from Bicep)."""
import json
import os
import sys
from diagrams import Diagram, Cluster
from diagrams.azure.compute import FunctionApps, ContainerRegistries
from diagrams.azure.web import AppServices, AppServicePlans
from diagrams.azure.integration import APIManagement
from diagrams.azure.security import KeyVaults
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.devops import ApplicationInsights
from diagrams.azure.network import VirtualNetworks, DNSZones
from diagrams.azure.identity import ManagedIdentities

# Map ARM resource types to diagrams node classes
RESOURCE_MAP = {
    "Microsoft.ApiManagement/service": ("APIM Service", APIManagement),
    "Microsoft.Web/serverfarms": ("App Service Plan", AppServicePlans),
    "Microsoft.Web/sites": ("App Service", AppServices),
    "Microsoft.Insights/components": ("App Insights", ApplicationInsights),
    "Microsoft.OperationalInsights/workspaces": ("Log Analytics", ApplicationInsights),
    "Microsoft.ContainerRegistry/registries": ("Container Registry", ContainerRegistries),
    "Microsoft.KeyVault/vaults": ("Key Vault", KeyVaults),
    "Microsoft.Storage/storageAccounts": ("Storage Account", StorageAccounts),
    "Microsoft.Network/virtualNetworks": ("Virtual Network", VirtualNetworks),
    "Microsoft.Network/privateDnsZones": ("Private DNS", DNSZones),
    "Microsoft.ManagedIdentity/userAssignedIdentities": ("Managed Identity", ManagedIdentities),
}

# Skip child/sub-resources and RBAC assignments for cleaner diagrams
SKIP_TYPES = {
    "Microsoft.Authorization/roleAssignments",
    "Microsoft.Web/sites/basicPublishingCredentialsPolicies",
    "Microsoft.KeyVault/vaults/secrets",
    "Microsoft.ApiManagement/service/namedValues",
    "Microsoft.ApiManagement/service/loggers",
    "Microsoft.ApiManagement/service/authorizationServers",
    "Microsoft.Storage/storageAccounts/blobServices",
    "Microsoft.Storage/storageAccounts/blobServices/containers",
    "Microsoft.Storage/storageAccounts/tableServices",
    "Microsoft.Storage/storageAccounts/tableServices/tables",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups",
}


def parse_arm_json(filepath):
    """Extract top-level resources from ARM JSON."""
    with open(filepath, "r") as f:
        arm = json.load(f)
    resources = []
    for r in arm.get("resources", []):
        rtype = r.get("type", "")
        if rtype not in SKIP_TYPES and rtype in RESOURCE_MAP:
            label, node_cls = RESOURCE_MAP[rtype]
            resources.append({"type": rtype, "label": label, "node_cls": node_cls})
    # Deduplicate by type (e.g., multiple Private DNS zones → single node)
    seen = set()
    unique = []
    for r in resources:
        if r["type"] not in seen:
            seen.add(r["type"])
            unique.append(r)
    return unique


def generate_diagram(arm_file, app_name, output_dir="diagrams"):
    """Generate a single architecture diagram from ARM JSON."""
    os.makedirs(output_dir, exist_ok=True)
    resources = parse_arm_json(arm_file)
    if not resources:
        print(f"No mappable resources found in {arm_file}")
        return None

    outpath = os.path.join(output_dir, f"architecture-{app_name}")
    with Diagram(
        f"{app_name} Architecture",
        filename=outpath,
        show=False,
        direction="LR",
        outformat="png",
    ):
        with Cluster(f"Resource Group: {app_name}"):
            nodes = []
            for r in resources:
                nodes.append(r["node_cls"](r["label"]))
            # Connect nodes in a logical flow
            for i in range(len(nodes) - 1):
                nodes[i] >> nodes[i + 1]

    return f"{outpath}.png"


# Diagram configurations: (ARM JSON path, app name)
DIAGRAMS = [
    ("/tmp/appservice.json", "weather-api"),
    ("/tmp/appservice.json", "star-wars-api"),
    ("/tmp/appservice.json", "soap-api"),
    ("/tmp/appservice.json", "odata-api"),
    ("/tmp/appservice.json", "movie-api"),
    ("/tmp/appservice.json", "web-app"),
    ("/tmp/fnapp.json", "appointments-api"),
    ("/tmp/apim.json", "apim-basicv2"),
    ("/tmp/fastapi.json", "fast-api"),
    ("/tmp/flask.json", "flask-app"),
]

if __name__ == "__main__":
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "diagrams"
    for arm_file, app_name in DIAGRAMS:
        if os.path.exists(arm_file):
            result = generate_diagram(arm_file, app_name, output_dir)
            if result:
                print(f"Generated: {result}")
        else:
            print(f"Skipped {app_name}: {arm_file} not found")
```

**Step 4: Publish to Wiki (extend existing pattern)**

```yaml
- name: Publish architecture diagrams to Wiki
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    WIKI_REPO="${GITHUB_REPOSITORY}.wiki"
    WIKI_DIR="wiki-checkout"

    git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${WIKI_REPO}.git" "${WIKI_DIR}" 2>/dev/null || {
      echo "Wiki not initialized"
      exit 1
    }

    # Remove old architecture diagrams (keep latest only)
    rm -f "${WIKI_DIR}"/architecture-*.png

    # Copy new diagrams to wiki root (required by GitHub Wiki)
    cp diagrams/architecture-*.png "${WIKI_DIR}/"

    # Create/update Architecture wiki page
    cat > "${WIKI_DIR}/Architecture-Diagrams.md" << 'EOF'
    # Architecture Diagrams

    Auto-generated from Bicep infrastructure-as-code files. Updated on every deployment.

    ## APIM Basic v2

    ![APIM BasicV2 Architecture](architecture-apim-basicv2.png)

    ## Backend APIs

    ### Weather API
    ![Weather API Architecture](architecture-weather-api.png)

    ### Star Wars API
    ![Star Wars API Architecture](architecture-star-wars-api.png)

    ### SOAP API
    ![SOAP API Architecture](architecture-soap-api.png)

    ### OData API
    ![OData API Architecture](architecture-odata-api.png)

    ### Movie Reviews API
    ![Movie API Architecture](architecture-movie-api.png)

    ### Web App (OpenID Connect)
    ![Web App Architecture](architecture-web-app.png)

    ### Flask App (MSAL Python)
    ![Flask App Architecture](architecture-flask-app.png)

    ### FastAPI App
    ![FastAPI Architecture](architecture-fast-api.png)

    ### Appointments API (Azure Functions)
    ![Appointments API Architecture](architecture-appointments-api.png)
    EOF

    cd "${WIKI_DIR}"
    git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    git config user.name "${GITHUB_ACTOR}"
    git add -A
    git diff --cached --quiet && echo "No changes" && exit 0
    git commit -m "Update architecture diagrams from Bicep - run #${GITHUB_RUN_NUMBER}"
    git push origin master 2>/dev/null || git push origin main 2>/dev/null || echo "Wiki push failed"
```

**Workflow Placement Options:**

| Option | Trigger | Pros | Cons |
|---|---|---|---|
| **A: New standalone workflow** | `push` on `infra/**/*.bicep`, `src/**/main.bicep`, `workflow_dispatch` | Clean separation, runs only when Bicep changes | Separate from deployment flow |
| **B: Add to `deploy-all.yml` `publish-wiki`** | After all 9 deploys complete | Runs with screenshots, single wiki push | Runs even if Bicep unchanged |
| **C: Add to `create-lab.yml`** | Full lab creation | Complete lab includes diagrams | Only runs on full lab deploy |

**Recommendation: Option A (standalone) + Option B (extend `deploy-all.yml`)**

Use **Option A** for on-demand/Bicep-change triggers, and **Option B** to include diagrams alongside screenshots in the full deployment report. Both share the same `generate_architecture_diagrams.py` script.

**Standalone workflow (`generate-architecture-diagrams.yml`):**

```yaml
name: Generate Architecture Diagrams

on:
  push:
    paths:
      - 'infra/appservice/main.bicep'
      - 'infra/fnapp/main.bicep'
      - 'infra/api-management-basicv2/main.bicep'
      - 'src/fast-api-app-insights/main.bicep'
      - 'src/msal-python-soln/python-flask-webapp/main.bicep'
      - 'scripts/generate_architecture_diagrams.py'
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  generate-diagrams:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Bicep CLI
        run: |
          curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
          chmod +x bicep && sudo mv bicep /usr/local/bin/

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install diagram dependencies
        run: |
          sudo apt-get update && sudo apt-get install -y graphviz
          pip install diagrams

      - name: Build ARM JSON from Bicep
        run: |
          bicep build infra/appservice/main.bicep --outfile /tmp/appservice.json
          bicep build infra/fnapp/main.bicep --outfile /tmp/fnapp.json
          bicep build infra/api-management-basicv2/main.bicep --outfile /tmp/apim.json
          bicep build src/fast-api-app-insights/main.bicep --outfile /tmp/fastapi.json
          bicep build src/msal-python-soln/python-flask-webapp/main.bicep --outfile /tmp/flask.json

      - name: Generate architecture diagrams
        run: python scripts/generate_architecture_diagrams.py diagrams

      - name: Publish to GitHub Wiki
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          WIKI_REPO="${GITHUB_REPOSITORY}.wiki"
          WIKI_DIR="wiki-checkout"

          git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${WIKI_REPO}.git" "${WIKI_DIR}" 2>/dev/null || {
            echo "Wiki not initialized. Please create a wiki page first."
            exit 1
          }

          rm -f "${WIKI_DIR}"/architecture-*.png
          cp diagrams/architecture-*.png "${WIKI_DIR}/"

          cat > "${WIKI_DIR}/Architecture-Diagrams.md" << 'WIKIEOF'
          # Architecture Diagrams

          Auto-generated from Bicep infrastructure-as-code files.

          ## APIM Basic v2
          ![APIM BasicV2](architecture-apim-basicv2.png)

          ## Weather API
          ![Weather API](architecture-weather-api.png)

          ## Star Wars API
          ![Star Wars API](architecture-star-wars-api.png)

          ## SOAP API
          ![SOAP API](architecture-soap-api.png)

          ## OData API
          ![OData API](architecture-odata-api.png)

          ## Movie Reviews API
          ![Movie API](architecture-movie-api.png)

          ## Web App (OpenID Connect)
          ![Web App](architecture-web-app.png)

          ## Flask App (MSAL Python)
          ![Flask App](architecture-flask-app.png)

          ## FastAPI App
          ![FastAPI](architecture-fast-api.png)

          ## Appointments API (Azure Functions)
          ![Appointments API](architecture-appointments-api.png)
          WIKIEOF

          cd "${WIKI_DIR}"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git config user.name "github-actions[bot]"
          git add -A
          git diff --cached --quiet && echo "No wiki changes" && exit 0
          git commit -m "Update architecture diagrams - $(date -u '+%Y-%m-%d')"
          git push origin master 2>/dev/null || git push origin main 2>/dev/null || echo "Wiki push failed"
```

#### Considered Alternatives

**Alternative 1: Mermaid `architecture-beta` diagrams**

* **Approach:** Write Mermaid `.mmd` files per Bicep template, render to PNG via `@mermaid-js/mermaid-cli`
* **Pros:** Native GitHub Markdown rendering (no image generation needed for repo README); lower dependency footprint (Node.js only)
* **Cons:** Limited Azure icons (only 5 built-in generic icons; requires Iconify registration for Azure logos); `architecture-beta` is a new/unstable feature; GitHub's Mermaid renderer may not support `architecture-beta` yet; custom Iconify icons don't render in GitHub Markdown natively
* **Why rejected:** Azure icon support is too limited. The diagrams would look generic rather than having the recognizable Azure resource icons the user wants ("nice pretty azure icons")

**Alternative 2: Draw.io (diagrams.net) headless export**

* **Approach:** Programmatically generate `.drawio` XML, export to PNG using `drawio --export`
* **Pros:** Excellent Azure icon library (already used in repo for `apimADSv2.drawio`); very polished output
* **Cons:** Generating `.drawio` XML programmatically is extremely complex (custom XML construction); headless export requires `xvfb-run` on Linux; no established library for programmatic Azure diagram generation in Draw.io format; high maintenance burden
* **Why rejected:** The XML generation complexity makes this impractical for automation. Draw.io is better suited for manual diagram creation (as currently used in `docs/assets/diagrams/`)

**Alternative 3: Bicep Visualizer (VS Code extension)**

* **Approach:** Use built-in `ms-azuretools.vscode-bicep` visualization
* **Pros:** Zero setup for local viewing; understands Bicep natively
* **Cons:** VS Code GUI only — no CLI, no headless, no export capability; uses basic resource-type icons (not official Azure architecture icons); cannot run in GitHub Actions
* **Why rejected:** Cannot be automated for CI/CD. Useful for local development but not for the continuous publishing requirement

**Alternative 4: Live Azure resource state (`az resource list` → diagram)**

* **Approach:** Query deployed Azure resources via `az resource list --resource-group ...` and generate diagrams from live state
* **Pros:** Shows actual deployed resources including runtime additions; could include resource health status
* **Cons:** Requires Azure credentials in GitHub Actions; shows drift from IaC intent; may include resources not defined in Bicep; authentication complexity; slower (API calls vs file parsing)
* **Why rejected:** The user specified "source of truth is usually the main.bicep" — modeling from IaC definition is more appropriate than querying live state

**Alternative 5: PSRule.Rules.Azure / arm-ttk**

* **Not applicable:** These are validation/compliance tools with zero diagram/visualization features

**Alternative 6: Infracost / Structurizr / C4**

* **Not applicable:** Infracost is Terraform-only with no diagram features; Structurizr/C4 operates at the wrong abstraction level (software architecture, not infrastructure topology)

## Potential Next Research

* Verify exact `diagrams` node class names for all Azure resource types used (run `pip install diagrams` locally and test imports)
  * Reasoning: Node class names may differ slightly between `diagrams` library versions
  * Reference: [diagrams Azure nodes docs](https://diagrams.mingrammer.com/docs/nodes/azure)
* Test Graphviz layout engines (`dot` vs `neato` vs `fdp`) for optimal visual layout of each template's resources
  * Reasoning: The default `dot` engine uses hierarchical layout; `neato` or `fdp` may produce better layouts for network-heavy diagrams (fnapp)
  * Reference: Graphviz documentation
* Prototype diagram grouping for the `fnapp` template (VNet subnet clusters, private endpoint grouping)
  * Reasoning: The Appointments API has ~24 resources and needs visual clustering to be readable
  * Reference: `diagrams` Cluster API
* Test `diagrams` `outformat="svg"` for scalable wiki images
  * Reasoning: SVG scales better than PNG for different screen sizes; but GitHub Wiki image rendering may prefer PNG
  * Reference: GitHub Wiki image handling
* Explore adding the diagram generation step to the existing `publish-wiki` job in `deploy-all.yml`
  * Reasoning: Combines screenshot + diagram publishing in a single wiki push
  * Reference: [deploy-all.yml](/.github/workflows/deploy-all.yml) lines 164-355

## Summary

| Aspect | Detail |
|---|---|
| **Selected Approach** | Python `diagrams` library + `bicep build` ARM JSON parser |
| **Why** | 42k stars, official Azure icons (v18), headless, PNG/SVG output, proven pattern (AWS CloudFormation Diagrams) |
| **Key Deliverables** | `scripts/generate_architecture_diagrams.py` + `.github/workflows/generate-architecture-diagrams.yml` |
| **Wiki Integration** | Extends existing `publish-wiki` pattern: overwrite old → push new to wiki root |
| **Trigger** | On Bicep file changes (`push` to `main`) + `workflow_dispatch` |
| **Diagrams Produced** | 10 PNG files: 1 APIM + 9 backends |
| **Alternatives Evaluated** | 6 (Mermaid, Draw.io, Bicep Visualizer, live Azure, PSRule, Infracost/C4) |
| **Research Documents** | 3 subagent files in `.copilot-tracking/research/subagents/2026-03-22/` |
