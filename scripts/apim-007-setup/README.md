---
title: APIM 007 setup scripts
description: One-time scripts that create the Azure DevOps tracking items and the Azure and GitHub prerequisites for the APIM 007 APIops CLI promotion demo
ms.date: 2026-10-06
ms.topic: how-to
---

## Purpose

Two one-time scripts prepare the APIM 007 demo. Neither runs from a workflow.

| Script | Purpose |
|---|---|
| `New-Apim007WorkItems.ps1` | Creates or reuses the Epic, the Feature and the five User Stories (S1 to S5) in `devopsabcs/OneProject`, adds parent links, and writes an ID map with the suggested `feature/<id>-apim007-*` branch names. |
| `Initialize-Apim007Environment.ps1` | Creates the tagged resource groups, a budget, user-assigned managed identities with federated credentials, ABAC-constrained role assignments and the nine GitHub environments with their secrets, variables and protection rules. |

> [!WARNING]
> `Initialize-Apim007Environment.ps1` creates billable Azure resources, managed identities and role assignments, and changes repository settings. You need subscription Owner and GitHub repository admin rights. Review the `-WhatIf` output before every real run.

## Prerequisites

* PowerShell 7.2 or later.
* Azure CLI signed in to the target tenant (`az login --tenant <tenant>`).
* For the work items script: `az extension add --name azure-devops`, then `az login` or `az devops login --organization https://dev.azure.com/devopsabcs`.
* For the environment script: GitHub CLI signed in with repository admin rights (`gh auth login`).

## Work items

Run the preview first, then the real run:

```powershell
./scripts/apim-007-setup/New-Apim007WorkItems.ps1 -WhatIf
./scripts/apim-007-setup/New-Apim007WorkItems.ps1
```

Pass `-ExistingEpicId <id>` to attach the Feature to an existing APIOps Epic. Items are matched by exact title, so a second run reuses them.

## Environment setup order

The environment script runs in two stages around the provisioning workflow:

1. Run `Initialize-Apim007Environment.ps1 -Stage Initial -WhatIf`, review the cost table, budget, expiry, reviewers and self-review choice, then run it without `-WhatIf`.
2. Run `infra-apim-007.yml` with `target=shared` to deploy the registry.
3. Run `Initialize-Apim007Environment.ps1 -Stage PostRegistry -RegistryName <registryName> -WhatIf`, then run it without `-WhatIf`.
4. Run `infra-apim-007.yml` with `target=dev`, then `target=prod`.

```powershell
./scripts/apim-007-setup/Initialize-Apim007Environment.ps1 -Stage Initial `
    -SubscriptionId <subscription-id> -TenantId <tenant-id> `
    -GitHubRepository devopsabcs-engineering/APIM_apim-landing-zone-accelerator `
    -BudgetAmount 150 -BudgetAlertEmail <email> -ExpiresOn 2026-12-31 `
    -ProdReviewers <github-login> -WhatIf
```

The `Initial` stage sets the repository variable `APIM007_ENABLED=true` as its last step, so the 007 workflows stay inactive until setup completes. Passing `-PreventSelfReview $false` lets a solo presenter approve their own prod release; the script records that reduced control in `APIM007_PREVENT_SELF_REVIEW`.

The AI gateway needs the `Microsoft.CognitiveServices` provider and an infra RBAC Administrator condition on each APIM resource group that also allows the Cognitive Services OpenAI User and Cognitive Services User roles for service principals. Environments set up before the AI gateway need one more `Initial` run; the script updates the existing condition in place.

> [!NOTE]
> The script refuses to continue when any `rg-apim-demo-007-*` resource group exists without the `apimDemo=007` tag. It never deletes resources.
