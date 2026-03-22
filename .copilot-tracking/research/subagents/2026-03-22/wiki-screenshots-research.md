# Research: Existing Deployment Screenshot Patterns and GitHub Wiki Publishing

## Research Topics

1. Find existing screenshot workflows and patterns in `.github/workflows/`
2. Examine the `docs/` and `docsLZ/` folders for diagrams and assets
3. Research the `create-lab.yml` workflow structure
4. Search for Mermaid, draw.io, or diagram files in the repo
5. Research GitHub Wiki automation patterns (existing in repo)
6. Search for existing Python scripts or tools in the repo

---

## 1. Screenshot Capture Pattern (Puppeteer-Based)

### Pattern Summary

The repo uses a consistent **Puppeteer-based screenshot capture** pattern across 8 of the 9 individual deploy workflows. The `deploy-appointments-api.yml` (Azure Functions) does **not** have a screenshot step.

### Workflows with Screenshot Capture

| Workflow | Artifact Name | Screenshot Target |
|----------|--------------|-------------------|
| `deploy-web-app.yml` | `screenshot-web-app` | Home page (`/`) |
| `deploy-weather-api.yml` | `screenshot-weather-api` | Swagger UI (`/swagger`) |
| `deploy-star-wars-api.yml` | `screenshot-star-wars-api` | Swagger UI (`/swagger`) |
| `deploy-soap-api.yml` | `screenshot-soap-api` | WSDL document |
| `deploy-odata-api.yml` | `screenshot-odata-api` | OData metadata |
| `deploy-movie-api.yml` | `screenshot-movie-api` | Swagger UI (`/swagger`) |
| `deploy-flask-app.yml` | `screenshot-flask-app` | Home page (`/`) |
| `deploy-fast-api.yml` | `screenshot-fast-api` | API docs (`/docs`) |

### Screenshot Capture Code Template

Each workflow follows this exact pattern (from `deploy-web-app.yml` lines 258-293):

```yaml
- name: Capture screenshot
  id: screenshot
  env:
    APP_NAME: ${{ needs.deploy-app.outputs.app_name }}
  run: |
    APP_URL="https://${APP_NAME}.azurewebsites.net"
    npm install puppeteer
    node -e "
      const puppeteer = require('puppeteer');
      (async () => {
        const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
        const page = await browser.newPage();
        await page.setViewport({ width: 1280, height: 720 });
        try {
          await page.goto('${APP_URL}', { waitUntil: 'networkidle2', timeout: 30000 });
        } catch (e) {
          console.log('Navigation warning:', e.message);
        }
        await page.screenshot({ path: 'screenshot.png' });
        await browser.close();
        console.log('Screenshot captured successfully');
      })().catch(e => { console.error('Screenshot failed:', e.message); process.exit(0); });
    "
    if [ -f screenshot.png ]; then
      echo "captured=true" >> "$GITHUB_OUTPUT"
    else
      echo "captured=false" >> "$GITHUB_OUTPUT"
    fi
- name: Upload screenshot artifact
  if: steps.screenshot.outputs.captured == 'true'
  uses: actions/upload-artifact@v4
  with:
    name: screenshot-web-app
    path: screenshot.png
    retention-days: 30
```

### Key Technical Details

- **Tool:** Puppeteer (npm package, installed inline per job)
- **Browser:** Headless Chromium (`headless: 'new'`)
- **Viewport:** 1280 × 720
- **Wait strategy:** `networkidle2` with 30-second timeout
- **Output:** Single `screenshot.png` per job
- **Artifact naming:** `screenshot-{app-name}` pattern
- **Retention:** 30 days
- **Error handling:** Graceful failure — process.exit(0) on error; does not fail the workflow
- **No browser automation framework needed** — raw Puppeteer only

---

## 2. Wiki Publishing Pattern (`deploy-all.yml`)

### `publish-wiki` Job Structure (lines 164-355)

The `deploy-all.yml` workflow has a **`publish-wiki`** job that runs after all 9 deployment jobs complete. This is the canonical pattern for publishing to the GitHub Wiki.

### Step-by-Step Flow

#### Step 1: Download Screenshot Artifacts

```yaml
- name: Download all screenshot artifacts
  uses: actions/download-artifact@v4
  with:
    pattern: screenshot-*
    path: screenshots
    merge-multiple: false
```

Downloads all artifacts matching `screenshot-*` pattern into a `screenshots/` directory. Each artifact gets its own subdirectory: `screenshots/screenshot-{app-name}/screenshot.png`.

#### Step 2: Collect Data and Build Wiki Page

- Fetches version info and runs smoke tests against all 9 app URLs using `curl`
- Builds a Markdown file (`wiki-report.md`) with:
  - Header with timestamp and workflow run link
  - Application status table (URL, Version, Smoke Test result, Version endpoint)
  - Screenshots section — iterates over `screenshots/screenshot-*/` directories
  - Flattens screenshot names: copies `screenshots/screenshot-{app}/screenshot.png` → `screenshots/screenshot-{app}-screenshot.png`
  - Deployment details table (Run ID, commit, timestamp)

#### Step 3: Publish to GitHub Wiki (lines 293-351)

```yaml
- name: Publish to GitHub Wiki
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    WIKI_REPO="${GITHUB_REPOSITORY}.wiki"
    WIKI_DIR="wiki-checkout"

    # Clone wiki repository
    git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${WIKI_REPO}.git" "${WIKI_DIR}" 2>/dev/null || {
      echo "Wiki not initialized. Creating initial wiki page..."
      mkdir -p "${WIKI_DIR}"
      cd "${WIKI_DIR}"
      git init
      git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${WIKI_REPO}.git"
      echo "# APIM Landing Zone Accelerator Wiki" > Home.md
      cd ..
    }

    # Create deployment reports directory
    mkdir -p "${WIKI_DIR}/Deployment-Reports"

    # Remove all old deployment report files — keep only the current run
    rm -f "${WIKI_DIR}"/Deployment-Reports/Deployment-Report-*.md

    # Remove old screenshot images from wiki root
    rm -f "${WIKI_DIR}"/screenshot-*.png

    # Copy flat-named screenshots to wiki repo root
    if [ -d screenshots ]; then
      for IMG in screenshots/screenshot-*.png; do
        if [ -f "${IMG}" ]; then
          cp "${IMG}" "${WIKI_DIR}/$(basename "${IMG}")"
        fi
      done
    fi

    # Copy report: dated version + latest alias
    DATE_STAMP=$(date -u '+%Y-%m-%d')
    cp wiki-report.md "${WIKI_DIR}/Deployment-Reports/Deployment-Report-${DATE_STAMP}-Run-${GITHUB_RUN_NUMBER}.md"
    cp wiki-report.md "${WIKI_DIR}/Deployment-Reports/Latest-Deployment-Report.md"

    # Update wiki index page
    {
      echo "# Deployment Reports"
      echo ""
      echo "**[Latest Deployment Report](Deployment-Reports/Latest-Deployment-Report)**"
    } > "${WIKI_DIR}/Deployment-Reports.md"

    # Commit and push
    cd "${WIKI_DIR}"
    git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    git config user.name "${GITHUB_ACTOR}"
    git add -A
    git diff --cached --quiet && echo "No wiki changes to commit" && exit 0
    git commit -m "Deployment report for run #${GITHUB_RUN_NUMBER} on $(date -u '+%Y-%m-%d')"
    git push origin master 2>/dev/null || git push origin main 2>/dev/null || echo "Wiki push failed - wiki may not be enabled"
```

### Key Wiki Publishing Details

- **Auth:** Uses `GITHUB_TOKEN` (automatically provided by GitHub Actions)
- **Clone URL:** `https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git`
- **Fallback:** If wiki not initialized, creates it from scratch with `git init`
- **Branch:** Tries `master` first, then `main` (GitHub Wiki default branch is `master`)
- **Image storage:** Screenshots stored in wiki repo root (GitHub Wiki serves images from root)
- **Overwrite strategy:** Deletes old `Deployment-Report-*.md` files and `screenshot-*.png` before writing new ones — **only keeps latest version**
- **Two copies of report:** A dated version (`Deployment-Report-{date}-Run-{number}.md`) and `Latest-Deployment-Report.md`
- **Index page:** `Deployment-Reports.md` links to the latest report
- **Permissions required:** `contents: write` in workflow permissions
- **Image references in wiki Markdown:** `![App Label](screenshot-{app}-screenshot.png)` with relative paths

---

## 3. `create-lab.yml` Workflow Structure

### Overview

File: `.github/workflows/create-lab.yml` (200 lines)
Purpose: Orchestrate full APIM lab environment creation as a single workflow.

### Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `instance_number` | string | `006` | APIM instance number |
| `location` | string | `canadacentral` | Azure region |
| `deploy_apis` | boolean | `true` | Deploy backend APIs |

### Permissions

```yaml
permissions:
  id-token: write
  contents: write
  pages: write
```

### Job Graph

```text
record-start-time (no deps)
├── deploy-apim (calls deploy-apim-basicv2.yml)
│   └─ deploy dev + prod, seed demo data
├── deploy-apis (calls deploy-all.yml)
│   └─ deploys all 9 backend APIs (includes publish-wiki internally)
│
├── publish-apiops-dev (needs deploy-apim + deploy-apis)
│   └─ calls run-publisher-with-env-006.yaml for dev-006
│
├── publish-apiops-prod (needs publish-apiops-dev)
│   └─ calls run-publisher-with-env-006.yaml for prod-006
│
└── lab-summary (always runs, needs all jobs)
    └─ Writes comprehensive summary to GITHUB_STEP_SUMMARY
```

### Key Notes

- `create-lab.yml` **does NOT** have its own screenshot or wiki steps
- It delegates screenshot capture and wiki publishing to `deploy-all.yml` (called via `deploy-apis`)
- The lab summary job writes to `$GITHUB_STEP_SUMMARY` (not wiki)
- Summary includes: Overview table, job results, resource groups, estimated monthly cost, next steps
- Mentions wiki in summary: "Run the deployment report workflow (`deploy-all.yml`) to generate the wiki report"

---

## 4. Diagram Assets Found in Repo

### `docs/assets/diagrams/`

| File | Type |
|------|------|
| `apimADSv2.drawio` | draw.io source file |
| `apimADSv2.png` | Exported PNG |
| `apimADSv2.svg` | Exported SVG |
| `apimADSv2.vsdx` | Visio source |

### `docs/assets/html/`

- `edit-diagram.html` — HTML page embedding `diagrams.net` iframe editor for editing `.drawio` files in-browser

### `docs/assets/images/`

Extensive collection (~200+ PNG/SVG files) covering:
- APIM portal screenshots (developer portal, APIs, products, subscriptions)
- Architecture diagrams (`apim-architecture-design-session-v2.png`, `apim-devops-architecture.png`)
- GitHub Actions pipeline screenshots
- ADO pipeline screenshots
- Auth flow diagrams
- App Gateway deployment screenshots
- Event Hub integration
- Key Vault integration
- OAuth2 flows

### `docs/assets/gifs/`

- `ApiOps.gif` — APIOps workflow animation
- `codespace.gif` — Codespace setup animation

### `docs/assets/slides/`

- `APIM.pptx` — APIM presentation
- `APIOps.pptx` — APIOps presentation

### `docsLZ/images/`

13 images including:
- `apim.png`, `arch.png`, `backend.png`, `networking.png`, `shared.png` — Architecture diagrams
- `APIM.vsdx` — Visio source
- Azure portal screenshots (cloud shell, resource groups, manual trigger, etc.)

### SVG Files (non-diagram)

- `docs/assets/images/protocols-roles.svg`
- `docs/assets/images/convergence-scenarios-native.svg`

### No Mermaid/PlantUML Files Found

- No `.mmd` files
- No `.puml` files
- No Mermaid rendering in any workflow

---

## 5. Scripts and Tools

### `scripts/` Folder

| File | Purpose |
|------|---------|
| `sanitize-artifacts-for-v2.ps1` | Cleans v1-specific references from artifacts for BasicV2 |
| `seed-apim-demo-data.ps1` | Seeds demo users and subscriptions |

### `tools/` Folder

| Path | Purpose |
|------|---------|
| `tools/code/` | C# solution (`code.sln`) — APIOps tooling |
| `tools/scripts/` | PowerShell scripts for extractor configuration |
| `tools/github_workflows/` | Additional workflow templates |
| `tools/azdo_pipelines/` | Azure DevOps pipeline templates |

### No Existing Diagram/Visualization Generation Scripts

No Python or PowerShell scripts for generating diagrams, Mermaid rendering, or automated visualization exist in the repo.

---

## 6. GitHub Wiki Automation Technical Details

### Authentication Pattern (Already Proven in Repo)

The repo uses `GITHUB_TOKEN` (not PAT) for wiki operations:

```bash
git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git" wiki-dir
```

**Note:** `GITHUB_TOKEN` works for wiki push when the workflow has `contents: write` permission AND the wiki has been initialized (at least one page created manually or via the API).

### Wiki Repo Structure

```text
{owner}/{repo}.wiki.git
├── Home.md                          # Wiki home page
├── Deployment-Reports.md            # Index page for reports
├── Deployment-Reports/
│   ├── Latest-Deployment-Report.md  # Always overwritten
│   └── Deployment-Report-{date}-Run-{number}.md  # Dated copy
├── screenshot-web-app-screenshot.png
├── screenshot-weather-api-screenshot.png
└── ... (images at root level)
```

### Image Serving Rules

- GitHub Wiki serves images from the **repo root** (not from subdirectories)
- Image references in wiki pages use relative paths: `![Alt](image-name.png)`
- No subdirectory-based image referencing supported
- Overwriting images: Just replace the file and push — Git handles versioning

### Overwrite vs History Strategy (Current Implementation)

The current implementation uses **overwrite (latest-only)**:

1. `rm -f` old report files and screenshot PNGs
2. Write new files
3. `git add -A` and push

This means only the latest deployment report and screenshots are kept. Git history preserves old versions if needed, but the wiki UI shows only the current state.

### Key Considerations for New Diagram Publishing

To publish architecture diagrams (Mermaid-rendered) to the wiki:

1. **Generate image** (PNG or SVG) in workflow
2. **Copy to wiki repo root** (follow existing pattern)
3. **Create/update wiki page** referencing the image
4. **Push to wiki repo**

Recommended naming: `architecture-{diagram-name}.png` to avoid collision with `screenshot-*` pattern.

---

## 7. `deploy-apim-basicv2.yml` — No Screenshot Pattern

The APIM BasicV2 deployment workflow does **not** capture screenshots. It focuses on:

- Deploying Bicep infrastructure for APIM dev and prod instances
- Seeding demo data (users, subscriptions, developer portal)
- No browser automation or puppeteer usage

This is notable because the user may want to add architecture diagram generation to this workflow or to `create-lab.yml`.

---

## 8. Appointments API — No Screenshot Pattern

`deploy-appointments-api.yml` is the only individual deploy workflow that does **not** have puppeteer screenshot capture. It deploys Azure Functions but skips the screenshot step entirely, though it does upload artifacts for container images.

---

## Summary of Findings

### What Exists

| Pattern | Location | Technology |
|---------|----------|------------|
| Screenshot capture | 8 deploy workflows | Puppeteer (inline npm install) |
| Screenshot artifact upload | 8 deploy workflows | `actions/upload-artifact@v4` |
| Screenshot collection | `deploy-all.yml` publish-wiki | `actions/download-artifact@v4` with pattern `screenshot-*` |
| Wiki page generation | `deploy-all.yml` publish-wiki | Bash script building Markdown |
| Wiki publishing | `deploy-all.yml` publish-wiki | Git clone/commit/push with GITHUB_TOKEN |
| Architecture diagrams | `docs/assets/diagrams/` | draw.io (`.drawio`, exported `.png`, `.svg`) |
| Portal screenshots | `docs/assets/images/` | 200+ pre-captured PNG files |
| Diagram editor | `docs/assets/html/edit-diagram.html` | Embedded diagrams.net iframe |

### What Does NOT Exist

- No Mermaid rendering in workflows
- No automated diagram generation from code/config
- No Python diagram scripts
- No PlantUML files
- No architecture diagram publishing to wiki
- No diagram generation in `create-lab.yml` or `deploy-apim-basicv2.yml`

---

## Next Research Potential

- How to integrate Mermaid CLI (`@mermaid-js/mermaid-cli`) into GitHub Actions for rendering `.mmd` → `.png`/`.svg`
- Best pattern for generating architecture diagrams from Azure resource state (e.g., `az resource list` → Mermaid)
- Whether to add diagram generation to `create-lab.yml` as a new job or to `deploy-all.yml`'s existing `publish-wiki` job
- How to structure wiki pages: separate Architecture page vs embedding in deployment report
