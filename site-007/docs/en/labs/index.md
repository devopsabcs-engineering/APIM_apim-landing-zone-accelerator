---
title: Lab map
description: The eleven APIOps 007 labs, in order, with what each one builds and the evidence it produces.
---

# Lab map

The labs build on each other. Do them in order the first time. Each lab ends with a **checkpoint** you can verify before you move on.

<div class="path-grid" markdown>

| Lab | You build | You prove |
|-----|-----------|-----------|
| [0 Setup](lab-00-setup.md) | Tools, identities, GitHub environments, budget | Federated identities with least-privilege roles |
| [1 Infrastructure](lab-01-infrastructure.md) | Registry, two Basic v2 APIM services, backends | A target manifest derived from fixed deployments |
| [2 Bundle](lab-02-bundle.md) | `artifacts.007/`, ownership filter, inventory | One bundle, two override files |
| [3 Baseline release](lab-03-baseline-release.md) | A frozen candidate deployed to dev, then prod | Approval gate, release state, receipts |
| [4 A-to-B](lab-04-promotion-a-to-b.md) | A visible policy change | Dev changes first, prod only after approval |
| [5 Extraction](lab-05-extraction-gitops.md) | A portal edit brought back to Git | Drift detection and a policy-only branch |
| [6 Rollback](lab-06-rollback.md) | Rollback, roll forward, refusals | Only trusted candidates can be redeployed |
| [7 AI infrastructure](lab-07-ai-infrastructure.md) | Azure OpenAI and Content Safety per environment | Keyless access with managed identity |
| [8 AI release](lab-08-ai-release.md) | AI API, team products, token limits | 401 / 200 / 429 / 403 and token metrics |
| [9 AI promotion](lab-09-ai-promotion-showback.md) | `ai-b` promotion and a prod quota change | Showback per team |
| [10 Teardown](lab-10-teardown.md) | Exact-ID removal of one environment | Nothing outside the lab is touched |

</div>

## How every lab is laid out

* **Overview**: duration, level, prerequisites and the checkpoint.
* **Steps**: copy-paste PowerShell, then an *Expected result* box.
* **Evidence**: the real output or screenshot from the recorded run.

!!! tip "Set your session variables once"
    Every lab uses the same PowerShell variables. Lab 0 shows how to set them. If you open a new terminal, paste that block again.

## Two ways to follow

* **Hands-on**: you run everything in your own subscription and repository copy. Budget about 6 hours and a few US dollars per day while the environments exist (two API Management Basic v2 instances dominate the cost).
* **Read-along**: you follow the recorded run through the evidence. Every lab shows the real results, so you can learn the model without deploying anything.
