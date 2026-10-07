---
title: Promote Azure API Management from dev to prod with APIOps
description: Hands-on labs that build a two-environment Azure API Management promotion pipeline with the APIops CLI, extraction GitOps, rollback and an AI gateway, with real evidence at every step.
hide:
  - toc
---

<div class="hero" markdown>

<p class="eyebrow">Hands-on labs · EN / FR · Windows + PowerShell + GitHub Actions</p>

# One frozen candidate, from dev to prod, with a human in charge

<p class="lead">
You will build <strong>APIM 007</strong>: two Azure API Management services (dev and prod), a Git repository that owns their configuration, and GitHub Actions that promote the <em>same</em> frozen candidate from dev to prod behind an approval, then extend it with an <strong>AI gateway</strong> for Azure OpenAI.
</p>

[Start with Lab 0](labs/lab-00-setup.md){ .md-button .md-button--primary }
[See the lab map](labs/index.md){ .md-button }

</div>

## The big idea

Git is the source of truth. One environment-neutral bundle (`artifacts.007/`) describes the APIs, backends, products, policies and named values. The [APIops CLI](https://github.com/Azure/apiops) publishes it to dev, tests it, waits for a human approval and publishes the **identical** bundle to prod. Only small, generated override files differ per environment.

<figure class="anim-frame" markdown>
![Animated diagram: a pull request merges to main, the release workflow freezes a candidate, publishes it to dev-007, tests it, waits for approval and publishes the same candidate to prod-007; an extraction loop brings portal edits from dev back into a pull request](../assets/anim/apiops-flow.svg)
<figcaption>APIOps 007 in one picture: build once, promote the same candidate, extract changes back to Git.</figcaption>
</figure>

## The promotion path at a glance

<ol class="flow-strip" aria-label="APIOps 007 promotion path: pull request, candidate, dev, plan, approval, prod, extraction">
  <li class="phase-card phase-idea">
    <span class="ico" aria-hidden="true">🔀</span>
    <span class="tag">Git</span>
    <strong>Pull request</strong>
    <span class="gate">bundle · Pester · lint</span>
  </li>
  <li class="phase-card phase-plan">
    <span class="ico" aria-hidden="true">🧊</span>
    <span class="tag">Freeze</span>
    <strong>Candidate</strong>
    <span class="gate">immutable release · SHA256</span>
  </li>
  <li class="phase-card phase-build">
    <span class="ico" aria-hidden="true">🧪</span>
    <span class="tag">Dev</span>
    <strong>dev-007</strong>
    <span class="gate">publish · extract · gateway tests</span>
  </li>
  <li class="phase-card phase-test">
    <span class="ico" aria-hidden="true">📋</span>
    <span class="tag">Plan</span>
    <strong>Prod plan</strong>
    <span class="gate">read-only summary</span>
  </li>
  <li class="phase-card phase-sign">
    <span class="ico" aria-hidden="true">🔐</span>
    <span class="tag">Approve</span>
    <strong>Reviewer</strong>
    <span class="gate">prod-007 environment</span>
  </li>
  <li class="phase-card phase-deploy">
    <span class="ico" aria-hidden="true">🚀</span>
    <span class="tag">Prod</span>
    <strong>prod-007</strong>
    <span class="gate">same candidate · same tests</span>
  </li>
  <li class="phase-card phase-prod">
    <span class="ico" aria-hidden="true">🔁</span>
    <span class="tag">GitOps</span>
    <strong>Extraction</strong>
    <span class="gate">portal edit → pull request</span>
  </li>
</ol>

!!! loop "Two loops you will meet in the labs"
    **Rollback:** any earlier *clean* candidate can be redeployed by its tag, with the same tests and the same approval.
    **Extraction:** an edit made in the dev portal is extracted, compared and projected into a pull request, so Git stays the source of truth.

## And then: an AI gateway

The same pipeline promotes an Azure OpenAI chat API. APIM authenticates to the model with its managed identity, applies per-team token limits, screens prompts with Azure AI Content Safety and emits token metrics for showback.

<figure class="anim-frame" markdown>
![Animated diagram: a client calls the APIM AI gateway with a team subscription key; APIM removes the key, checks the team token limit, screens the prompt with Content Safety, calls Azure OpenAI with its managed identity and emits token metrics to Application Insights](../assets/anim/ai-gateway-flow.svg)
<figcaption>The AI gateway: keys stay at the edge, limits per team, safety before the model, metrics after.</figcaption>
</figure>

## The labs

| Lab | Title | Duration | Level |
|-----|-------|----------|-------|
| [0](labs/lab-00-setup.md) | Prerequisites and one-time setup | 45 min | Intermediate |
| [1](labs/lab-01-infrastructure.md) | Provision dev and prod with Bicep | 40 min | Intermediate |
| [2](labs/lab-02-bundle.md) | The environment-neutral bundle | 30 min | Intermediate |
| [3](labs/lab-03-baseline-release.md) | First release: candidate, dev, approval, prod | 45 min | Intermediate |
| [4](labs/lab-04-promotion-a-to-b.md) | A-to-B promotion | 25 min | Intermediate |
| [5](labs/lab-05-extraction-gitops.md) | Extraction GitOps: portal edit to pull request | 30 min | Advanced |
| [6](labs/lab-06-rollback.md) | Rollback, roll forward and failure tests | 35 min | Advanced |
| [7](labs/lab-07-ai-infrastructure.md) | AI gateway infrastructure | 30 min | Advanced |
| [8](labs/lab-08-ai-release.md) | AI gateway release and tests | 35 min | Advanced |
| [9](labs/lab-09-ai-promotion-showback.md) | AI promotion and token showback | 25 min | Advanced |
| [10](labs/lab-10-teardown.md) | Teardown and cleanup | 20 min | Intermediate |

!!! evidence "Everything here really ran"
    Every screenshot, run number and output on this site comes from the recorded run on 2026-10-06 and 2026-10-07 against `dev-007` and `prod-007`. See the [evidence index](evidence.md).

## Who this is for

* Platform and API teams who run Azure API Management in more than one environment.
* DevOps engineers who want a promotion model where prod receives exactly what dev tested.
* Architects evaluating an AI gateway pattern for Azure OpenAI with chargeback.

You need comfort with PowerShell, Git and GitHub Actions, and Owner rights on an Azure subscription you can use for a lab.
