---
title: "Lab 5: Extraction GitOps - portal edit to pull request"
description: Make a policy edit in the dev portal, extract dev with the APIops CLI, detect the drift, project the edit into the bundle and push a branch for review.
---

# Lab 5: Extraction GitOps - portal edit to pull request

<span class="chip phase-prod"><span aria-hidden="true">🔁</span> Extraction</span> <span class="chip phase-idea">30 min</span> <span class="chip phase-plan">Advanced</span>

## Overview

<div class="lab-meta" markdown>

| Item | Details |
|------|---------|
| **Duration** | 30 minutes |
| **Level** | Advanced |
| **Prerequisites** | [Lab 4](lab-04-promotion-a-to-b.md) complete, dev `clean` on a candidate built from `main` |
| **Checkpoint** | A branch `apim007/extract-<run-id>` that changes only `policy.xml` files |
| **Next lab** | [Lab 6: Rollback](lab-06-rollback.md) |

</div>

People still use the portal. Extraction GitOps brings an approved dev edit back into Git, so the next release carries it to prod through the normal approval, and nothing drifts silently.

## Learning objectives

By the end of this lab, you will be able to:

* Run the dev-only extraction workflow.
* Explain the safety rules: dev must run `main`, only policies are projected, raw extraction is evidence only.
* Review the projected branch and decide to merge it or not.

## Steps

### Step 1: Make an edit in the dev portal

In the Azure portal, open the dev API Management service, then **Products** > **team-retail** > **Policies** (or **APIs** > **Weather** > **All operations** > **Policies**). Add a response header in the outbound section:

```xml
<set-header name="x-demo-team" exists-action="override">
    <value>retail</value>
</set-header>
```

Save.

### Step 2: Run the extraction

```powershell
gh workflow run extract-apiops-007.yml --repo $Repo
$runId = gh run list --repo $Repo --workflow extract-apiops-007.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --repo $Repo
gh run view $runId --repo $Repo --json jobs --jq '.jobs[].steps[] | select(.conclusion != "skipped") | [.name, .conclusion] | @tsv'
```

<figure class="screenshot-frame" markdown>
![PowerShell window listing the extraction job steps: target manifest, require dev to run main, extract, secret scan, compare and project, Pester, bundle validation, push branch](../../assets/img/lab-05/05-01-extract-run.png)
<figcaption>Run <code>37665497460</code>: the edit was detected, projected, tested and pushed.</figcaption>
</figure>

<figure class="screenshot-frame" markdown>
![GitHub Actions run page of Extract APIops 007 with the job succeeded and the projected policy changes listed in the summary](../../assets/img/lab-05/05-04-gh-extract-run.png)
<figcaption>The job summary lists the projected policy files.</figcaption>
</figure>

### Step 3: Review the projected branch

```powershell
git fetch origin apim007/extract-$runId
git diff --stat origin/main FETCH_HEAD
git diff -w origin/main FETCH_HEAD -- artifacts.007/products/team-retail/policy.xml
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing a one-file diff that adds the x-demo-team set-header to the team-retail product policy](../../assets/img/lab-05/05-02-projected-diff.png)
<figcaption>Only the policy file changed. Endpoint, operation or schema drift would fail the comparison instead.</figcaption>
</figure>

<figure class="screenshot-frame" markdown>
![GitHub compare page between main and the apim007/extract branch showing one commit that changes the team-retail policy](../../assets/img/lab-05/05-05-gh-projected-branch.png)
<figcaption>Open a pull request from this branch to promote the edit, or delete the branch and revert dev.</figcaption>
</figure>

!!! info "Why not an automatic pull request?"
    In this organization, policy blocks `GITHUB_TOKEN` from creating pull requests, so the workflow pushes the branch and logs a warning. You open the pull request yourself; it runs the normal validation.

### Step 4: See the safety rule

Extraction refuses to run when dev is not running `main` (for example after a rollback), because a pull request built from an old candidate would revert newer work:

```powershell
gh run view 37619952350 --repo $Repo --log-failed | Select-String "not running main"
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing the error message: dev is not running main; release main first](../../assets/img/lab-05/05-03-extract-refusal.png)
<figcaption>Run <code>37619952350</code>: refused on purpose while dev ran a rollback candidate.</figcaption>
</figure>

!!! checkpoint "Checkpoint"
    A pushed `apim007/extract-<run-id>` branch whose diff touches only `policy.xml` files. In the recorded run the edit was a demo, so dev was restored to the bundle version and the branch was kept for review.
