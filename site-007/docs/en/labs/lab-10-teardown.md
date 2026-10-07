---
title: "Lab 10: Teardown and cleanup"
description: Remove one environment's API Management, backends, monitoring and AI accounts by exact resource ID, verify nothing else was touched, and handle soft-deleted resources.
---

# Lab 10: Teardown and cleanup

<span class="chip phase-human"><span aria-hidden="true">🧹</span> Teardown</span> <span class="chip phase-idea">20 min</span> <span class="chip phase-plan">Intermediate</span>

## Overview

<div class="lab-meta" markdown>

| Item | Details |
|------|---------|
| **Duration** | 20 minutes |
| **Level** | Intermediate |
| **Prerequisites** | Any earlier lab |
| **Checkpoint** | The run's *Verify removal* step passes; the other environment is untouched |
| **Next** | [Evidence index](../evidence.md) |

</div>

Teardown never deletes a resource group and never uses wildcards. It derives exact resource IDs from the fixed deployments, checks every tag, then removes those IDs only.

## Learning objectives

By the end of this lab, you will be able to:

* Tear down one environment with an explicit confirmation.
* Read the inventory that was removed and the Owner follow-up list.
* Recover from soft-deleted API Management and AI accounts.

## Steps

### Step 1: Run the teardown for dev

```powershell
gh workflow run teardown-apim-007.yml --repo $Repo -f environment=dev -f confirm=delete-apim-007-dev
```

Prod teardown needs `confirm=delete-apim-007-prod` and a reviewer approval on `prod-007-teardown`.

### Step 2: Read the inventory and the result

```powershell
gh run view <run-id> --repo $Repo --json jobs --jq '.jobs[].steps[] | [.name, .conclusion] | @tsv'
```

<figure class="screenshot-frame" markdown>
![PowerShell window listing the teardown steps: verify confirmation, build exact resource inventory, remove resources by ID, verify removal, owner follow-up summary](../../assets/img/lab-10/10-01-teardown-run.png)
<figcaption>Run <code>37624727789</code>: the dev teardown rehearsal.</figcaption>
</figure>

<figure class="screenshot-frame" markdown>
![GitHub Actions run page of Teardown APIM 007 for dev with the inventory of removed resource IDs in the summary](../../assets/img/lab-10/10-02-gh-teardown-run.png)
<figcaption>The summary lists every removed ID and the follow-up actions for the Owner.</figcaption>
</figure>

### Step 3: Handle soft-deleted resources

API Management and the AI accounts stay soft-deleted for 48 hours, and their names are derived from the resource group, so re-provisioning the same environment fails until the records are gone. No workflow removes soft-delete records; the Owner does it on purpose:

```powershell
az apim deletedservice purge --service-name <apim-name> --location $Location
az cognitiveservices account purge --location canadaeast --resource-group rg-apim-demo-007-dev-apim --name <account-name>
```

Then restore the environment with `infra-apim-007.yml` (`target=dev`) and a release from `main`.

### Step 4: Clean up everything when you are done

1. Tear down `prod` and `dev`.
2. Delete the five `rg-apim-demo-007-*` resource groups in the portal (this also removes the identities and the registry).
3. Delete the budget and the nine GitHub environments.

!!! checkpoint "Checkpoint"
    *Verify removal* passed, and the other environment's gateway still answers.
