<!-- markdownlint-disable-file -->
# Release Changes: APIM On-Demand Lab — Phase 2, 3 & 4

**Related Plan**: apim-on-demand-lab-plan.instructions.md
**Implementation Date**: 2026-03-21

## Summary

Implement migration automation, post-deployment configuration, single-click lab provisioning, and migration validation for the APIM on-demand lab environment.

## Changes

### Added

* `scripts/sanitize-artifacts-for-v2.ps1` — PowerShell script that sanitizes v1 APIops artifacts for BasicV2 publishing (handles 8 migration gaps: external groups, product-group associations, subscriptions, OAuth2 settings, Key Vault refs, instrumentationKey, workspaces, instance URLs)
* `scripts/seed-apim-demo-data.ps1` — PowerShell script that seeds demo admin user and product subscriptions in a fresh APIM instance via Azure REST API
* `.github/workflows/validate-artifacts.yml` — Standalone workflow that scans artifact folders for v1-specific references (005 patterns, Key Vault refs, external groups, subscription ownerIds, OAuth2 authorizationServerIds, workspace artifacts) and reports findings in the workflow summary
* `.github/workflows/create-lab.yml` — Master orchestrator workflow that provisions the entire APIM lab environment with a single dispatch: deploys APIM BasicV2 (dev + prod) and 9 backend APIs in parallel, then publishes APIops artifacts to both environments; includes wall-clock timing and cost estimation summary
* `.github/workflows/teardown-lab.yml` — Teardown workflow that destroys all lab resources (9 API resource groups + APIM dev/prod resource groups) with `APIM_Lab_Teardown` environment approval gate; all deletions are async (no-wait)

### Modified

* `.github/workflows/run-publisher-with-env-006.yaml` — Added sanitizer step after checkout and before publisher execution; added pre-publish validation step that produces GitHub warning annotations for v1 references before the sanitizer fixes them
* `infra/api-management-basicv2/main.bicep` — Added `createOAuth2Server` and `oAuth2ClientId` parameters; added conditional OAuth2 authorization server resource (`weatherappoauth`)
* `.github/workflows/deploy-apim-basicv2.yml` — Added `seed_demo_data` workflow input; added conditional AAD identity provider configuration step (via `az rest`) and demo data seeding step in both deploy-dev and deploy-prod jobs; added `workflow_call` trigger with matching inputs for reusable workflow support
* `.github/workflows/deploy-all.yml` — Added `workflow_call` trigger with matching inputs for reusable workflow support from the master orchestrator

### Removed

## Additional or Deviating Changes

## Release Summary
