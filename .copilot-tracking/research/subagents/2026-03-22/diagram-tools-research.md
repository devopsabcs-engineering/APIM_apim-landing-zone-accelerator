# Research: Tools and Approaches for Generating Azure Architecture Diagrams from Bicep Files

## Research Status: Complete

---

## Research Topics

1. Bicep Visualizer — VS Code built-in, headless CI/CD capability, export formats, Azure icon quality
2. ARM Template Viewer — Programmatic visualization of ARM/Bicep
3. PSRule.Rules.Azure — Diagram export features
4. Azure Resource Visualizer (Portal) — Automation capability
5. Diagrams as Code (Python `diagrams` library) — Azure nodes, Bicep/ARM parsing, output formats, GitHub Actions
6. Mermaid Diagrams — Azure icon support, GitHub Wiki rendering
7. Draw.io / diagrams.net — Programmatic generation, Azure icons, CLI export
8. Structurizr / C4 Model — Relevance for infrastructure diagrams
9. Azure/bicep-visualizer or similar OSS — CLI tools for .bicep to diagrams
10. Custom approach: Parse Bicep to generate diagram code
11. arm-ttk or other ARM tooling — Visualization capabilities
12. Infracost or similar — Visualization features
13. GitHub Wiki publishing automation
14. Best practices for storing generated diagrams

---

## Findings

### 1. Bicep Visualizer (VS Code Extension)

**How it works:** Built-in feature of the Bicep VS Code extension (`ms-azuretools.vscode-bicep`). Renders an interactive graph of resources and dependencies. Invoked via `Bicep: Open Bicep Visualizer`.

**Headless CI/CD:** No. Tightly coupled to VS Code's GUI. No CLI equivalent exists. `bicep build` compiles to ARM JSON only — no visual output.

**Export format:** None exportable. Renders as an interactive webview inside VS Code.

**Azure icons:** Basic resource-type icons, not official Azure architecture icons.

**Verdict:** Not suitable for automated CI/CD diagram generation. Developer tool for local use only.

| Criterion | Rating |
|---|---|
| Azure icons | Basic (not official) |
| Headless CI/CD | No |
| Output formats | None (VS Code webview only) |
| Quality/Polish | Low (functional, not presentational) |
| Maintenance burden | None (built-in) |
| Community adoption | High (part of official extension) |

---

### 2. ARM Template Viewer / az bicep decompile

**ARM Template Viewer** is a VS Code extension. Like Bicep Visualizer, it is VS Code-only with no headless export.

**`az bicep decompile`** converts ARM JSON back to Bicep — no visual output.

**`bicep build`** compiles Bicep to ARM JSON. The resulting JSON is a key building block for parsing resource definitions as input to other diagram tools.

**Verdict:** Not directly useful for diagram generation, but `bicep build` is critical for the custom approach.

---

### 3. PSRule.Rules.Azure

**What it is:** 500+ rules for validating Azure IaC against the Well-Architected Framework. 437 GitHub stars.

**Diagram support:** None. Purely a validation/compliance tool producing text-based pass/fail reports.

**Verdict:** Not applicable.

---

### 4. Azure Resource Visualizer (Portal)

**What it is:** Browser-based interactive UI within the Azure Portal showing deployed resources.

**Automation:** Cannot be automated. No API or CLI for export.

**Verdict:** Not suitable for CI/CD automation.

---

### 5. Diagrams as Code (Python `diagrams` library) — TOP RECOMMENDATION

**What it is:** Python library (42.1k GitHub stars, 173 contributors, 2.3k dependents) that draws cloud architecture diagrams in code. Uses Graphviz for rendering.

**Azure node types:** Extensive coverage across 20+ categories:

- `azure.compute` — VM, AKS, FunctionApps, ContainerApps, VMSS
- `azure.network` — ApplicationGateway, Firewall, LoadBalancers, VirtualNetworks, FrontDoors, PrivateEndpoint, NSG, DNS
- `azure.database` — CosmosDb, SQLDatabases, CacheForRedis
- `azure.integration` — APIManagement, ServiceBus, EventGridTopics, LogicApps
- `azure.security` — KeyVaults, Defender, Sentinel
- `azure.storage` — StorageAccounts, BlobStorage, DataLake
- `azure.identity` — ActiveDirectory, ManagedIdentities
- `azure.web` — APIManagementServices, AppServices, StaticApps
- `azure.monitor` — ApplicationInsights, LogAnalyticsWorkspaces
- `azure.devops` — APIManagementServices, Pipelines

**Icons:** Official-style Azure icons (PNG format). Updated to Azure_Icons_v18 as of 5 months ago.

**Output formats:** PNG (default), SVG, PDF, DOT.

**GitHub Actions integration:**

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.11'
- run: |
    sudo apt-get install -y graphviz
    pip install diagrams
    python generate_diagram.py
```

**Related projects using this approach:**

- **AWS CloudFormation Diagrams** — CLI script generating AWS diagrams from CloudFormation. Directly analogous.
- **KubeDiagrams** — Generates Kubernetes diagrams from manifest files.
- **Cloudiscovery** — Analyzes cloud resources and generates diagrams.

| Criterion | Rating |
|---|---|
| Azure icons | Yes — official-style, regularly updated |
| Headless CI/CD | Yes — fully scriptable |
| Output formats | PNG, SVG, PDF, DOT |
| Quality/Polish | High — professional diagrams |
| Maintenance burden | Medium — requires custom parser |
| Community adoption | Very high (42.1k stars) |
| Limitations | Requires Graphviz; auto-generated layout |

---

### 6. Mermaid Diagrams

**Architecture diagram support:** Mermaid v11.1.0+ added `architecture-beta` diagram type for cloud architectures.

**Azure icon support:** 5 built-in icons (`cloud`, `database`, `disk`, `internet`, `server`). Custom icons via Iconify (200k+ icons). Official Azure icons are not built-in. Requires Iconify registration for Azure logos.

**GitHub Wiki rendering:** GitHub natively renders Mermaid in Markdown — no image generation needed. However, GitHub's Mermaid renderer may lag behind `architecture-beta` support.

**Mermaid CLI:** `mmdc` renders Mermaid to PNG/SVG headlessly:

```bash
npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png
```

| Criterion | Rating |
|---|---|
| Azure icons | Limited (Iconify workaround needed) |
| Headless CI/CD | Yes — via mermaid-cli |
| Output formats | PNG, SVG, PDF |
| Quality/Polish | Medium |
| Maintenance burden | Low |
| Community adoption | Very high generally; architecture-beta is new |
| Limitations | Beta feature; limited Azure icons; GitHub rendering lag |

---

### 7. Draw.io / diagrams.net

**Azure icon libraries:** Comprehensive built-in Azure icon library.

**CLI export:** Desktop app supports command-line export:

```bash
drawio --export --format png --output diagram.png diagram.drawio
xvfb-run drawio --export --format png diagram.drawio  # headless Linux
```

**Programmatic generation:** Uses XML format (`.drawio`). No mature library for programmatic Azure diagram generation. XML construction is complex.

| Criterion | Rating |
|---|---|
| Azure icons | Yes — comprehensive built-in |
| Headless CI/CD | Yes — with xvfb |
| Output formats | PNG, SVG, PDF, VSDX |
| Quality/Polish | Very high |
| Maintenance burden | High — complex XML format |
| Community adoption | Very high (52k+ stars for desktop) |
| Limitations | Programmatic generation is difficult |

---

### 8. Structurizr / C4 Model

**Relevance:** C4/Structurizr is for software architecture decomposition (systems, containers, components), not infrastructure topology. Wrong abstraction level for Bicep visualization.

**Verdict:** Not recommended.

---

### 9. Azure/bicep-visualizer or Similar OSS CLI

**Finding:** No standalone CLI tool exists. Bicep Visualizer is VS Code extension only. ARM Visualizer (armviz.io) is deprecated.

**Verdict:** Gap in tooling. Custom solution required.

---

### 10. Custom Approach: Parse Bicep → Generate Diagram Code — RECOMMENDED

**Pipeline:**

```
.bicep → bicep build → ARM JSON → Python parser → diagrams library → PNG/SVG
```

**Steps:**

1. `bicep build main.bicep --outfile main.json`
2. Parse ARM JSON — extract `resources` array (type, name, dependsOn)
3. Map ARM types to `diagrams` nodes:

```python
RESOURCE_MAP = {
    "Microsoft.ApiManagement/service": ("azure.integration", "APIManagement"),
    "Microsoft.Network/virtualNetworks": ("azure.network", "VirtualNetworks"),
    "Microsoft.KeyVault/vaults": ("azure.security", "KeyVaults"),
    "Microsoft.Storage/storageAccounts": ("azure.storage", "StorageAccounts"),
}
```

4. Generate and execute diagram code → PNG/SVG output

**Full GitHub Actions workflow:**

```yaml
name: Generate Architecture Diagram
on:
  push:
    paths: ['infra/**/*.bicep']
  workflow_dispatch:

jobs:
  generate-diagram:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Bicep CLI
        run: |
          curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
          chmod +x bicep && sudo mv bicep /usr/local/bin/

      - name: Install dependencies
        run: |
          sudo apt-get install -y graphviz
          pip install diagrams

      - name: Build ARM JSON from Bicep
        run: bicep build infra/main.bicep --outfile infra/main.json

      - name: Generate diagram
        run: python scripts/generate_diagram.py

      - name: Clone Wiki and publish
        run: |
          git clone https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.wiki.git wiki
          mkdir -p wiki/images
          cp architecture_diagram.png wiki/images/
          cd wiki
          cat > Architecture-Diagram.md << 'WIKIEOF'
          # Architecture Diagram
          Auto-generated from Bicep files. Updated on push.
          ![Architecture Diagram](images/architecture_diagram.png)
          WIKIEOF
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git diff-index --quiet HEAD || git commit -m "Update architecture diagram"
          git push
```

---

### 11. arm-ttk (ARM Template Test Toolkit)

Validates ARM template quality. No visualization capability.

**Verdict:** Not applicable.

---

### 12. Infracost

Cloud cost estimates for Terraform/OpenTofu only. Does not support Bicep/ARM. No architecture diagrams.

**Verdict:** Not applicable.

---

## GitHub Wiki Publishing Automation

### How GitHub Wikis Work with Git

Every wiki is a Git repository at `https://github.com/{owner}/{repo}.wiki.git`. Supports Markdown. Filenames become page titles. Images stored in the wiki repo. Only default branch changes go live.

### Key Implementation Notes

- `GITHUB_TOKEN` has push permission to wiki repo by default.
- Wiki must be initialized (create one page via UI first).
- Use `git diff-index --quiet HEAD ||` to avoid empty commits.
- Store images in `images/` subdirectory within wiki repo.

### Best Practices for Diagram Storage

| Approach | Pros | Cons |
|---|---|---|
| **Wiki repo** (recommended) | Clean separation; wiki renders images; no main repo bloat | Requires wiki setup |
| **Main repo `/docs`** | Single source of truth; reviewed in PRs | Binary bloat |
| **GitHub Releases** | No repo bloat; versioned | Hard to reference |

**Recommendation:** Wiki repo for generated images, generation script in main repo.

---

## Ranked List by Suitability

| Rank | Tool | Score | Rationale |
|---|---|---|---|
| **1** | **Python `diagrams` + Custom Parser** | ★★★★★ | Best Azure icons, headless, high quality, 42k stars |
| **2** | **Mermaid (architecture-beta)** | ★★★☆☆ | Native GitHub rendering, but limited Azure icons |
| **3** | **Draw.io (headless export)** | ★★★☆☆ | Excellent icons, but programmatic generation is complex |
| **4** | **Bicep Visualizer** | ★★☆☆☆ | Local dev only, no export |
| **5** | **ARM Template Viewer** | ★★☆☆☆ | VS Code only |
| **6** | **Structurizr / C4** | ★☆☆☆☆ | Wrong abstraction level |
| **7-10** | **PSRule, Portal, Infracost, arm-ttk** | ☆☆☆☆☆ | No diagram features |

---

## Clarifying Questions

1. Which Bicep entry point file(s) in the `infra/` directory should be used?
2. What level of detail is desired — every resource, or key components only?
3. Should the diagram include resource group visual clusters?
4. Is SVG preferred over PNG for wiki display?

---

## References

- Python `diagrams`: https://diagrams.mingrammer.com/ | https://github.com/mingrammer/diagrams
- Azure nodes: https://diagrams.mingrammer.com/docs/nodes/azure
- AWS CloudFormation Diagrams (analogous): https://github.com/philippemerle/AWS-CloudFormation-Diagrams
- KubeDiagrams: https://github.com/philippemerle/KubeDiagrams
- Bicep Visualizer: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/visual-studio-code#visualize
- Mermaid architecture: https://mermaid.js.org/syntax/architecture.html
- Mermaid icons: https://mermaid.js.org/config/icons.html
- PSRule.Rules.Azure: https://github.com/Azure/PSRule.Rules.Azure
- draw.io desktop: https://github.com/jgraph/drawio-desktop
- GitHub Wiki docs: https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages
