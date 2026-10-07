---
title: Glossary
description: The APIOps 007 terms used across the labs, from bundle and candidate to release state, overrides and token limits.
---

# Glossary

## Promotion terms

| Term | Meaning |
|------|---------|
| **APIops CLI** | `@azure-tools/apiops-cli`, the product-group command-line tool that extracts and publishes API Management configuration as files. Pinned to 1.0.4. |
| **Bundle** | `artifacts.007/`: the environment-neutral API Management configuration in the CLI's native folder layout. |
| **Ownership filter** | `configuration.007.ownership.yaml`: the only resources the pipeline may publish or extract. |
| **Expected inventory** | `configuration.007.expected-inventory.json`: an independent list of files, operations and override targets used by every check. |
| **Overrides** | A generated JSON file that sets per-environment values (service URLs, backend URLs, AI limits) at publish time. |
| **Target manifest** | Exact resource IDs and URLs of one environment, derived from the fixed deployments `apim007-*-<env>`. |
| **Candidate** | One frozen, immutable GitHub prerelease (`apim007-candidate-<run>-<sha>`) holding the bundle, tooling, scripts and image digests. |
| **Release state** | The `apim007-release-state` named value in each APIM service: current candidate, hash, status and history. |
| **Clean / dirty / deploying** | Release-state statuses: verified, unknown after a failure, or being written. |
| **Receipt** | A JSON record of what a deploy job deployed (candidate, hashes, images, AI evidence). |
| **Extraction GitOps** | Extract dev, compare with the bundle, project allowed policy edits into a branch. |

## AI gateway terms

| Term | Meaning |
|------|---------|
| **AI gateway** | APIM in front of Azure OpenAI: keys at the edge, managed identity to the model, limits, safety and metrics. |
| **Team product** | `team-retail` or `team-finance`: an APIM product with one subscription and its own token limits. |
| **`llm-token-limit`** | APIM policy that limits tokens per minute and per period for a counter key (here the subscription). |
| **`llm-content-safety`** | APIM policy that sends the prompt to Azure AI Content Safety before the model. |
| **`llm-emit-token-metric`** | APIM policy that emits prompt, completion and total token metrics with custom dimensions. |
| **Blocklist** | A Content Safety list with a fixture term that the tests use to trigger a deterministic block. |
| **Showback** | Reporting token use per team from the emitted metrics. |
