---
title: "Lab 10: Teardown and cleanup"
description: Remove one or both environments by exact resource ID, handle soft-deleted resources, reset Azure to a clean slate and start the labs again from Lab 0.
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
* Reset the subscription and repository to a clean slate and start again from Lab 0.

## Steps

### Step 1: Run the teardown for dev

```powershell
gh workflow run teardown-apim-007.yml --repo $Repo -f environment=dev -f confirm=delete-apim-007-dev
```

Prod teardown needs `confirm=delete-apim-007-prod` and a reviewer approval on `prod-007-teardown`.

To remove both environments in one run, choose `all`. The run starts one job per environment; the prod job still waits for its reviewer:

```powershell
gh workflow run teardown-apim-007.yml --repo $Repo -f environment=all -f confirm=delete-apim-007-all
```

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

### Step 4: Reset Azure to a clean slate

Do this when you finish, or before you run the labs again from the start. Only the Owner can run these commands; no workflow has the rights to, by design. Keep the order: soft-deleted records must be removed while their resource groups still exist.

1. Tear down both environments and approve the prod job on `prod-007-teardown`:

    ```powershell
    gh workflow run teardown-apim-007.yml --repo $Repo -f environment=all -f confirm=delete-apim-007-all
    ```

2. Purge the soft-deleted API Management services and AI accounts:

    ```powershell
    az apim deletedservice list -o json | ConvertFrom-Json | Where-Object name -like 'apim-*-007-*' |
        ForEach-Object { az apim deletedservice purge --service-name $_.name --location $Location -o none }
    az cognitiveservices account list-deleted -o json | ConvertFrom-Json | Where-Object name -like '*-apim007-*' |
        ForEach-Object { az cognitiveservices account purge --name $_.name --location $_.location --resource-group ($_.id -split '/')[8] -o none }
    ```

3. Remove the Log Analytics workspaces for good. Teardown leaves them soft-deleted for 14 days, and a new workspace with the same name would bring back the old data. Recover each one, then delete it with `--force`:

    ```powershell
    az monitor log-analytics workspace list-deleted-workspaces -o json | ConvertFrom-Json | Where-Object name -like 'log-apim-*-007-*' |
        ForEach-Object {
            $rg = ($_.id -split '/')[4]
            az monitor log-analytics workspace recover -g $rg -n $_.name -o none
            az monitor log-analytics workspace delete -g $rg -n $_.name --force true -y -o none
        }
    ```

4. Delete the five resource groups and the budget. Deleting the groups also removes the identities, their federated credentials, the registry and the role assignments scoped to them. It takes 10 to 30 minutes:

    ```powershell
    az group list --tag apimDemo=007 --query "[].name" -o tsv | ForEach-Object { az group delete -n $_ --yes --no-wait }
    az consumption budget delete --budget-name budget-apim-demo-007
    ```

5. Delete the nine GitHub environments and the two repository variables:

    ```powershell
    'apim-007-build', 'apim-007-shared-infra', 'dev-007', 'dev-007-infra', 'dev-007-teardown',
    'prod-007', 'prod-007-infra', 'prod-007-plan', 'prod-007-teardown' |
        ForEach-Object { gh api -X DELETE "repos/$Repo/environments/$_" }
    gh variable delete APIM007_ENABLED --repo $Repo
    gh variable delete APIM007_PREVENT_SELF_REVIEW --repo $Repo
    ```

6. Check that nothing is left. When the group deletions finish, each command returns no 007 names:

    ```powershell
    az group list --tag apimDemo=007 --query "[].name" -o tsv
    az apim deletedservice list --query "[].name" -o tsv
    az cognitiveservices account list-deleted --query "[].name" -o tsv
    az monitor log-analytics workspace list-deleted-workspaces --query "[].name" -o tsv
    gh api "repos/$Repo/environments?per_page=100" --jq '.environments[].name | select(test("007"))'
    ```

The reset keeps the GitHub Pages site, the GitHub releases and any extract branches. The release history lived in API Management, so the old releases cannot be used for a rollback on the new services.

### Step 5: Start again from Lab 0

The resource names are derived from the resource groups, so the new run reuses the same names. That is why Step 4 purges the soft-deleted records first.

1. [Lab 0](lab-00-setup.md), steps 4 to 6: run `-Stage Initial` with `-WhatIf`, then apply it with a new `-ExpiresOn` date. It recreates the resource groups, identities, roles, budget, GitHub environments and variables.
2. [Lab 1](lab-01-infrastructure.md), step 2: run the infra workflow with `target=shared`, then `-Stage PostRegistry` with the registry name from the run summary.
3. [Lab 1](lab-01-infrastructure.md), step 3: provision dev, then prod.
4. Continue with [Lab 2](lab-02-bundle.md) and the labs that follow.

!!! checkpoint "Checkpoint"
    *Verify removal* passed, and the other environment's gateway still answers. After a full reset, the checks in Step 4 return no 007 names.
