---
title: Troubleshooting
description: Fixes for the problems met in the recorded APIOps 007 run - workflows, releases, extraction, AI gateway and local tooling.
---

# Troubleshooting

## Workflows and releases

| Symptom | Cause and fix |
|---------|---------------|
| Every 007 job is skipped | The repository variable `APIM007_ENABLED` is not `true`. Finish the setup script (Lab 0). |
| `Signed-in tenant or subscription does not match` | The environment variables `EXPECTED_TENANT_ID` / `EXPECTED_SUBSCRIPTION_ID` differ from the federated identity's context. Re-run setup. |
| Infra fails with a name conflict | A soft-deleted APIM or AI account holds the name. See [Lab 10, step 3](labs/lab-10-teardown.md#step-3-handle-soft-deleted-resources). |
| `Plan prod-007` fails on protection | `prod-007` lost its reviewer, its `main`-only branch policy, or allows admin bypass. Re-run setup. |
| `deploying owned by an in-progress run` | Another release is writing to that environment. Wait, or cancel the other run. |
| Prod `dirty` blocks a release | Re-run the failed jobs (same candidate) or roll back to a history entry. Never hand-edit the state. |
| Freeze fails with `HTTP 403 Resource not accessible by integration` | Seen once and not reproduced. Re-run the whole workflow; check that the job still has `contents: write`. |
| A queued run disappeared | GitHub keeps one pending job per concurrency group. Re-run it; nothing was deployed. |

## Extraction

| Symptom | Cause and fix |
|---------|---------------|
| `dev is not running main; release main first` | Dev runs a rollback or an older candidate. Release `main`, then extract. |
| The comparison fails on an operation or schema | Only policies are projected. Make API shape changes through the bundle and a pull request. |
| No pull request was opened | Organization policy blocks `GITHUB_TOKEN` from creating pull requests. Open it from the pushed branch. |

## AI gateway

| Symptom | Cause and fix |
|---------|---------------|
| `401` with a key | The key belongs to another product, or the subscription is suspended. Re-run `Set-Apim007TeamSubscriptions.ps1`. |
| `500` from the model call | The APIM identity lacks *Cognitive Services OpenAI User*, or the role has not propagated yet (wait a few minutes). |
| T3 never gets `429` | The team's tokens per minute is too high for a 10-call burst. Lower it in `configuration.007.ai-settings.json`. |
| T5 finds no metrics | Ingestion lag, or the service diagnostic lacks `metrics: true`. Query `AppMetrics` in the workspace after a few minutes. |
| `403 Public access is disabled` from your laptop | Expected when an AI account allows only private access; test through APIM instead. |

## Local tooling

| Symptom | Cause and fix |
|---------|---------------|
| `apiops` not found | Run `npm ci --ignore-scripts` in `tools/apiops-cli` and use `./tools/apiops-cli/node_modules/.bin/apiops.cmd`. |
| `npm warn EBADENGINE` with `required: { node: '>=22 <23' }` | Your Node.js is not version 22. Install `OpenJS.NodeJS.22`, remove or switch away from the other version, then run `npm ci` again. See [Lab 0, step 1](labs/lab-00-setup.md#step-1-install-and-check-the-tools). |
| `az` fails on parentheses on Windows | `az.cmd` is a batch shim; quote JMESPath queries, or sort and filter in PowerShell. |
| Accents display as garbage | Set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`. |
