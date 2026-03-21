# Workspace Documentation Research

## Research Topics

- Full content of README.md at workspace root
- Full content of READMELZ.md at workspace root
- Complete listing of docs/ and docsLZ/ folders
- Content of documentation files in docs/

## Findings

### README.md (Root)

The root README.md is a very short file about AAD automations:

```markdown
# AAD automations

Various scripts and tools for scripting around Azure Active Directory, B2C etc.

* [B2C (Azure AD B2C)](/b2c)
```

**Key Insight**: This is only 3 lines. It describes the repo as containing AAD automation scripts and tools with a link to the B2C folder.

---

### READMELZ.md (Root)

READMELZ.md is the **Enterprise-Scale-APIM** landing zone accelerator documentation. It covers:

- **Enterprise-Scale Architecture**: Six design areas (Identity/Access, Network, Security, Management, Governance, Platform Automation/DevOps) with links to Microsoft CAF documentation
- **Reference Implementation 1**: App Gateway + internal APIM + Azure Functions backend
  - Architectural diagrams referenced from `/docsLZ/images/`
  - Deployment via Bicep (primary), ARM, Terraform (planned)
  - GitHub Action: `es-apim.yml`
- **Contributing** and **Trademarks** sections (standard Microsoft OSS boilerplate)

---

### docs/ Folder Structure

The `docs/` folder is a **Jekyll-based GitHub Pages site** for APIOps documentation using the "just-the-docs" theme.

**Top-level files:**
- `.devcontainer/` - Dev container config
- `.github/` - GitHub configs
- `.gitignore`
- `.vscode/` - VS Code settings
- `404.html` - Custom 404 page
- `CODE_OF_CONDUCT.md`
- `favicon.ico`
- `Gemfile` / `Gemfile.lock` - Ruby/Jekyll dependencies
- `index.markdown` - Site homepage (same as README.md essentially)
- `LICENSE`
- `README.md` - APIOps code of conduct, versions, about, guide, wiki links
- `SECURITY.md`
- `SUPPORT.md`
- `_config.yml` - Jekyll config (title: "APIOps - Documentation", theme: just-the-docs)
- `_includes/` - Jekyll includes (contains `js/`)

**`docs/apiops/` - Main APIOps documentation sections:**

| Section | Files |
|---------|-------|
| `0-labPrerequisites/` | `index.md`, `apim-prereq-0-1.md`, `apim-basic-concepts-0-2.md` |
| `1-supportedScenarios/` | `index.md` |
| `2-apimCreation/` | `index.md` |
| `3-apimTools/` | `index.md`, extractor/publisher tool docs, AzDO/GitHub/GitLab pipeline setup guides (old/new versions) |
| `4-extractApimArtifacts/` | `index.md`, AzDO/GitHub extraction pipeline docs |
| `5-publishApimArtifacts/` | `index.md`, publishing pipelines, scenario-based publishing |
| `6-supportingIndependentAPITeams/` | `index.md` |
| `7-additionalTopics/` | `index.md`, content, rerunning failed builds, supported resources |
| `8-contributing/` | `index.md`, contribution guide, issue submission, minor updates, codespaces |

**`docs/assets/` - Static assets:**
- `diagrams/` - Architecture diagrams
- `excel/` - Excel files
- `gifs/` - Animated GIFs (e.g., ApiOps.gif)
- `html/` - HTML files
- `images/` - Static images (e.g., apim-logo-transparent.png)
- `slides/` - Presentation slides

---

### docsLZ/ Folder Structure

The `docsLZ/` folder contains the **Landing Zone deployment documentation**:

- `README.md` - Detailed step-by-step deployment guide covering:
  1. Fork/clone the repository
  2. GitHub-to-Azure authentication (Service Principal, OIDC)
  3. Service Principal creation via Az CLI
  4. Federated Credentials setup (Azure Portal/CLI/PowerShell)
  5. GitHub Secrets configuration (7 required secrets)
  6. Running the es-apim.yml workflow
  7. Deployed resources (4 resource groups)
  8. Function and API deployment (Azure DevOps pipelines)

- `images/` - Supporting screenshots and diagrams:
  - `apim.png`, `APIM.vsdx` (Visio source)
  - `arch.png` - Architecture diagram
  - `az-account-show.jpg`
  - `backend.png`, `shared.png`, `networking.png` - Module outputs
  - `clone-repo.png`, `cloud_shell.png`
  - `deployed-items.png`, `resource_groups.png`
  - `manual_trigger.png`, `secrets.png`

---

### docs/README.md Content Summary

The docs README.md covers the APIOps tool:
- **Code of Conduct**: Guidelines for GitHub repo navigation (wiki, releases, issues)
- **Video Guide**: Two YouTube tutorial links (360 overview, step-by-step AzDO setup)
- **Versions**: Pre-3.0 vs post-3.0 delivery methodology changes
- **About**: APIOps applies DevOps concepts to Azure API Management, version-controlling APIM infrastructure
- **Complementary Guide**: 400-level hands-on lab at https://azure.github.io/apiops/
- **Wiki**: Resource-focused deep dives at https://github.com/Azure/apiops/wiki
- **Roadmap**: Project board tracking
- **Supporting Tools**: APIM Dev Portal migration tool link
- **Contributing** and **Trademarks** (standard Microsoft OSS)

---

## Key Discoveries

1. **Two distinct documentation sets**: `docs/` is for APIOps (CI/CD tooling for APIM), `docsLZ/` is for the Landing Zone Accelerator (infrastructure deployment)
2. **Root README.md is minimal** - only covers AAD automations, not the primary repo purpose
3. **READMELZ.md is the main architecture doc** - covers Enterprise-Scale-APIM architecture and reference implementations
4. **docs/ is a full Jekyll site** published via GitHub Pages with the just-the-docs theme
5. **8 documentation sections** in the APIOps guide covering prerequisites through contributing
6. **docsLZ/ is deployment-focused** with step-by-step instructions and screenshot images

## Status

**Complete** - All requested files read and folder structures enumerated.
