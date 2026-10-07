---
title: About these labs
description: Who built the APIOps 007 labs, how the evidence was captured, and how to build the site locally.
---

# About these labs

APIOps 007 is a lab built on the [APIM landing zone accelerator](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator) by the devopsabcs-engineering team. It shows the [Azure APIOps](https://github.com/Azure/apiops) approach with the product-group APIops CLI, applied to a dev-to-prod promotion with approvals, rollback, extraction GitOps and an AI gateway.

## How the evidence was captured

* **Terminal screenshots** run real, read-only commands and render the output with headless Microsoft Edge. Identifiers are masked, and keys never appear.
* **GitHub screenshots** come from the real workflow runs, releases and pull requests.
* **Animations** are hand-written SVG with CSS animation, in English and French, and respect *reduced motion* settings.

The capture scripts live in `site-007/scripts/`.

## Build the site locally

```powershell
Set-Location site-007
python -m pip install -r requirements.txt
mkdocs serve
```

Open `http://127.0.0.1:8000/`. `mkdocs build --strict` must pass before a pull request, together with `python scripts/check_parity.py` and `python scripts/check_images.py`.

## Licence

Content under the repository's MIT licence. Azure, GitHub and Microsoft Edge are trademarks of Microsoft.
