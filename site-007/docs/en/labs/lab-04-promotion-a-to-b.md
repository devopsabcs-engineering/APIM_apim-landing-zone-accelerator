---
title: "Lab 4: A-to-B promotion"
description: Change a visible policy header from baseline-a to candidate-b, show dev with the new value while prod still has the old one, then approve and show prod catch up.
---

# Lab 4: A-to-B promotion

<span class="chip phase-sign"><span aria-hidden="true">🔀</span> Promotion</span> <span class="chip phase-idea">25 min</span> <span class="chip phase-plan">Intermediate</span>

## Overview

<div class="lab-meta" markdown>

| Item | Details |
|------|---------|
| **Duration** | 25 minutes |
| **Level** | Intermediate |
| **Prerequisites** | [Lab 3](lab-03-baseline-release.md) complete, both environments `clean` |
| **Checkpoint** | Both gateways return `x-demo-release: candidate-b` |
| **Next lab** | [Lab 5: Extraction GitOps](lab-05-extraction-gitops.md) |

</div>

This is the demo moment: the same change is visible in dev while prod still serves the previous release, until a human approves.

## Learning objectives

By the end of this lab, you will be able to:

* Make an observable configuration change through a pull request.
* Prove with response headers which release each environment serves.
* Show from the run history that prod waited for the reviewer.

## Steps

### Step 1: Check the current release headers

Every API policy sets three response headers: `x-demo-environment`, `x-demo-release` and `x-demo-backend-host`.

```powershell
$Gateways = '<dev-apim-name>', '<prod-apim-name>'
foreach ($g in $Gateways) {
    "== $g"
    (Invoke-WebRequest "https://$g.azure-api.net/weather/api/Version" -SkipHttpErrorCheck).Headers.GetEnumerator() |
        Where-Object Key -like 'x-demo-*' | ForEach-Object { "$($_.Key): $($_.Value)" }
}
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing the x-demo-environment, x-demo-release and x-demo-backend-host headers returned by the dev and prod gateways](../../assets/img/lab-04/04-01-gateway-headers.png)
<figcaption>Each environment reports its own name and its own backend host, and the same release value.</figcaption>
</figure>

### Step 2: Change A to B through a pull request

```powershell
git switch -c feature/<work-item>-candidate-b
foreach ($p in 'artifacts.007/apis/weather/policy.xml', 'artifacts.007/apis/software-version/policy.xml') {
    (Get-Content $p -Raw).Replace('<value>baseline-a</value>', '<value>candidate-b</value>') | Set-Content $p -NoNewline
}
git commit -am "feat(artifacts): promote candidate-b AB#<work-item>"
git push -u origin HEAD
gh pr create --repo $Repo --fill
```

Merge the pull request when the checks pass. The release starts automatically.

### Step 3: Show dev ahead of prod

While `Deploy prod-007` waits for approval, run the header loop from step 1 again.

!!! success "Expected result"
    Dev returns `x-demo-release: candidate-b`. Prod still returns `baseline-a`.

### Step 4: Approve and show prod catch up

Approve `prod-007` (Lab 3, step 3), wait for the run to finish, and run the header loop again: both return `candidate-b`.

```powershell
gh run view 37616892784 --repo $Repo --json jobs --jq '.jobs[] | [.name, .conclusion, .startedAt, .completedAt] | @tsv'
gh api repos/$Repo/actions/runs/37616892784/approvals --jq '.[] | [.environments[0].name, .state, .user.login] | @tsv'
```

<figure class="screenshot-frame" markdown>
![PowerShell window with the job timeline of the A-to-B run, showing Deploy dev-007 finishing well before Deploy prod-007 starts, and the prod-007 approval](../../assets/img/lab-04/04-02-promotion-timeline.png)
<figcaption>Run <code>37616892784</code>: dev was done long before prod started, and prod started only after the approval.</figcaption>
</figure>

!!! checkpoint "Checkpoint"
    Both gateways return `candidate-b`, and both release states record the new candidate as `clean`.
