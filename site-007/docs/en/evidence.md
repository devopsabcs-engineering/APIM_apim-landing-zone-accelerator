---
title: Evidence index
description: Every workflow run, candidate, pull request and measurement from the recorded APIOps 007 run, with links to the lab that explains it.
---

# Evidence index

All results on this site come from one recorded run against `dev-007` and `prod-007` on 2026-10-06 and 2026-10-07. Run numbers are GitHub Actions run IDs in [devopsabcs-engineering/APIM_apim-landing-zone-accelerator](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions).

## Promotion pipeline

| Evidence | Value | Lab |
|----------|-------|-----|
| Contract capture | Run `37554025334` | [2](labs/lab-02-bundle.md) |
| Baseline A release | Run `37610973282`, candidate `apim007-candidate-6-51da660`, `baseline-a` in both | [3](labs/lab-03-baseline-release.md) |
| A-to-B promotion | Run `37616892784`: dev showed `candidate-b` while prod still showed `baseline-a` | [4](labs/lab-04-promotion-a-to-b.md) |
| Extraction to branch | Run `37618679494`: a dev portal edit projected into `apis/weather/policy.xml` | [5](labs/lab-05-extraction-gitops.md) |
| Rollback by tag | Run `37618926825` to `apim007-candidate-6-51da660` | [6](labs/lab-06-rollback.md) |
| Extraction refusal | Run `37619952350`: "dev is not running main" | [5](labs/lab-05-extraction-gitops.md) |
| Roll forward | Run `37620134897` from `main` | [6](labs/lab-06-rollback.md) |
| Untrusted tags | Runs `37621756882` (no release) and `37621889176` (not in history) | [6](labs/lab-06-rollback.md) |
| Simulated dev gate failure | Run `37622061716`; reconciled by `37622712361` | [6](labs/lab-06-rollback.md) |
| Dev teardown rehearsal | Run `37624727789`; restored by infra run `37626106546` | [10](labs/lab-10-teardown.md) |

## AI gateway

| Evidence | Value | Lab |
|----------|-------|-----|
| AI provisioning | Infra runs `37652034002` (dev) and `37652742332` (prod) | [7](labs/lab-07-ai-infrastructure.md) |
| Rejected prod deployment | Run `37658029033`: AI scripts without the AI bundle; guard added in PR #29 | [3](labs/lab-03-baseline-release.md), [8](labs/lab-08-ai-release.md) |
| Baseline AI release | Run `37660072964`, candidate 18: T1-T5 passed in dev and prod | [8](labs/lab-08-ai-release.md) |
| AI A-to-B | Run `37663312626`, candidate 19: dev `ai-b` while prod `baseline-ai`, then prod `ai-b` | [9](labs/lab-09-ai-promotion-showback.md) |
| Extraction, no drift | Run `37665255654` with product policies owned | [5](labs/lab-05-extraction-gitops.md) |
| Product policy projection | Run `37665497460`, branch `apim007/extract-37665497460` | [5](labs/lab-05-extraction-gitops.md) |
| Showback (`Total Tokens`, 1 day) | dev: team-finance 2072, team-retail 206; prod: team-finance 1097, team-retail 86 (including the evidence capture calls) | [9](labs/lab-09-ai-promotion-showback.md) |

## Pull requests and work items

| Pull requests | Scope |
|---------------|-------|
| #14 to #24 | Promotion pipeline, fixes found at runtime, runbook (Feature 4802) |
| #25 | AI infrastructure (story 4809) |
| #26 | AI release scripts and tests (story 4811) |
| #27, #28, #29 | AI workflow integration and the AI step guard (story 4812) |
| #30 | AI bundle (story 4810) |
| #31, #32 | `ai-b` promotion, runbook and evidence (story 4813) |

## Issues found and fixed at runtime

* A leftover native exit code after a tolerated `az` "not found" lookup failed the first dev release (PR #16).
* `approvalRequired` is rejected on a product without subscriptions; server defaults (`isAgent`, omitted `http` type, the built-in `administrators` group) needed normalizing in the extraction comparison.
* `peter-evans/create-pull-request` is not on the organization's allowed-actions list; extraction now pushes a branch with `git`.
* The extractor redacts literal `set-query-parameter` values, so the AI policy does not set `api-version`.
* A prod finance limit of 2000 tokens per minute could not reach `429` within the 10-call burst; prod finance is 500.
* The AI release step originally ran whenever the scripts existed; it now requires `aiSettings` in the candidate inventory.
