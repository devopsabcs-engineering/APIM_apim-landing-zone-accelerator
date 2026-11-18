---
title: APIOps 007 presenter runbook
description: Timing, metadata checks, approval pause and recovery for the bilingual APIOps promotion demonstration
---

## Timing and preparation

Use slides 1 through 8 for a 15 to 20 minute session. Allow 7 minutes for
concepts, 8 to 10 minutes for the demonstration and 2 minutes for questions.
Slides 9 and 10 are reference material. Both decks include speaker notes.

Stage and warm the baseline before speaking. A complete release can exceed
the talk duration. Keep a completed release's summaries, approval evidence
and receipts open as a fallback; distinguish recorded evidence from live steps.

* [English deck](APIOps-007-English.pptx)
* [French deck](APIOps-007-Francais.pptx)
* [English contact sheet](APIOps-007-English-contact.png)
* [French contact sheet](APIOps-007-Francais-contact.png)
* [Full operational runbook](../../../docs/apim-007-apiops-cli.md)

## Restoration evidence

Verified at 2026-11-18T02:47:38Z. Shared, dev and prod infrastructure are
deployed. The baseline API release and runtime gates passed in both environments.

* Approved source: `f27cffeb2b159f642a70f1cdf07fc272110f42cd`
* Initial setup and PostRegistry setup completed
* [Shared infrastructure succeeded](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions/runs/44220520881)
* [Dev infrastructure succeeded](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions/runs/44221013079)
* [Prod infrastructure succeeded](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions/runs/44221033168)
* [Fresh source validation passed](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions/runs/44221107160)
* [Baseline API release succeeded](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions/runs/44222021165)
* [Frozen baseline candidate](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/releases/tag/apim007-candidate-31-f27cffe)

Azure reports `provisioningState=Succeeded` for both Basic v2 services:

* Dev: `apim-dev-007-uovzcyp6yypu2`, gateway <https://apim-dev-007-uovzcyp6yypu2.azure-api.net>
* Prod: `apim-prod-007-p4afmw2tk5j4m`, gateway <https://apim-prod-007-p4afmw2tk5j4m.azure-api.net>

The human approved this baseline's normal GitHub `prod-007` environment review
as `emmanuelknafo`. No environment protection was bypassed. The later description
change still requires its own review and production approval.

## Verified demo starting point

Both release states are `clean` on candidate `apim007-candidate-31-f27cffe`,
with archive SHA-256
`316d5b552293221fa82412de10e1a9cb995e75d8f080ba16da4cd3766989a70c`.
Independent ARM reads show `description: null` for Weather in both targets.
Both live checks return HTTP 200, `x-demo-release: baseline-a` and application
version `1.0.62076.0`:

* [Dev Weather version](https://apim-dev-007-uovzcyp6yypu2.azure-api.net/weather/api/Version)
* [Prod Weather version](https://apim-prod-007-p4afmw2tk5j4m.azure-api.net/weather/api/Version)

The workflow also passed backend/gateway tests, AI subscription, rate-limit and
content-safety checks, extraction comparison and second-publish verification.
Both receipts identify the same source, archive, application version and image
digests. Target manifests and overrides differ by environment, as intended.
The production hashes match the human-approved read-only plan.

* [Dev receipt](baseline-evidence/receipt-dev-007/receipt.json)
* [Prod receipt](baseline-evidence/receipt-prod-007/receipt.json)
* [Independent metadata and health evidence](baseline-evidence/metadata-health.json)
* [Receipt and recovery verification](baseline-evidence/verification-summary.json)

The retained archive passed the existing verifier, including all 50 files and
digest-form image references. The existing read-only rollback gate accepts this
tag/hash from both clean histories. No rollback was executed. Recheck live state
before presenting; these results establish the starting point, not future health.

## Read-only comparison

Use the approved subscription and discover service names from the isolated
resource groups. These commands do not change API metadata.

```powershell
$subscription = '64c3d212-40ed-4c6d-a825-6adfbdf25dad'
$devGroup = 'rg-apim-demo-007-dev-apim'
$prodGroup = 'rg-apim-demo-007-prod-apim'
$devApim = az apim list --subscription $subscription --resource-group $devGroup --query '[0].name' -o tsv
$prodApim = az apim list --subscription $subscription --resource-group $prodGroup --query '[0].name' -o tsv
az apim api show --subscription $subscription --resource-group $devGroup --service-name $devApim --api-id weather --query '{name:name,description:description}' -o json
az apim api show --subscription $subscription --resource-group $prodGroup --service-name $prodApim --api-id weather --query '{name:name,description:description}' -o json
az apim nv show --subscription $subscription --resource-group $devGroup --service-name $devApim --named-value-id apim007-release-state --query value -o tsv
az apim nv show --subscription $subscription --resource-group $prodGroup --service-name $prodApim --named-value-id apim007-release-state --query value -o tsv
```

Stop if any command fails. Before the demo both states must be `clean`, with
the same candidate tag/hash, and both descriptions must match. A gateway 200
proves health, not the description. Use ARM or the Azure portal for metadata.

## Description promotion

1. Show the unchanged Weather description in dev and prod using the commands above.
2. Create branch `feature/4833-weather-description-promotion` from current main.
3. In `artifacts.007/apis/weather/apiInformation.json`, add only the property below under `properties`. Do not edit the normalized OpenAPI specification.
4. Commit with `AB#4833`, open a PR targeting main, wait for validation and review, then merge with `Fixes AB#4833` in the PR description.
5. Open the triggered **Release APIops 007** run. Show the frozen candidate and successful dev tests. Wait for the read-only prod plan and production approval pause.
6. Read both descriptions again: dev has the new description; prod still has the baseline. Show the candidate identity and prod plan.
7. As the human approver, review and approve `prod-007` in GitHub. Do not bypass the environment protection.
8. After prod succeeds, rerun the comparison. Both descriptions must match the new text, both states must be `clean`, and both receipts must identify the same candidate archive hash.

```json
"description": "APIOps 007 - reviewed promotion demo"
```

The description change has intentionally not been applied during preparation.
The 007 extractor only projects API/product policies into PRs, so do not edit
the description in the portal and expect this extraction workflow to import it.
There is no CLI `promote` command: the workflow publishes one frozen candidate
to two targets using target-specific overrides.

## Release and recovery plan

Owner and production approver: `emmanuelknafo`. Restore shared infrastructure,
then dev/prod infrastructure, validate approved main, then run the baseline
release through dev, read-only prod planning and the normal human approval.
Do not present the environment as ready before runtime gates pass.

Stop promotion on failed health, contract, extraction, integrity or state gates.
Retain the failed run and receipts. For a failed baseline, retry the same
candidate through the existing workflow; never hand-edit release state to clean.
A fresh environment has no earlier trusted clean candidate to roll back to.

The verified recovery point for the description demo is
`apim007-candidate-31-f27cffe`, with the archive SHA-256 recorded above and in
both receipts. If recovery is needed, obtain approval and dispatch
**Release APIops 007** with `rollback_candidate_tag` set to that tag.
The workflow verifies history/hash, revalidates dev, plans prod and requires
human prod approval again. Rollback is not atomic and does not delete entities
introduced by later candidates. No rollback or deletion is pre-approved here.

## Cost and support reminders

The two APIM Basic v2 instances are approximately US$300/month together,
plus approximately US$26.28/month for two B1 plans, US$5.06/month for ACR,
and telemetry/AI usage. The US$150 budget sends alerts; it is not a spending cap.
The November 20 expiry is not automatic teardown. Resources continue billing
until the owner runs the documented teardown after separate approval.

The CLI is maintained by the Microsoft API Management product group, is MIT
open source and uses community GitHub Issues support without a guaranteed
response time. APIM service support is separate. The approved lab pins CLI
1.0.4; do not upgrade tooling during the demonstration.
