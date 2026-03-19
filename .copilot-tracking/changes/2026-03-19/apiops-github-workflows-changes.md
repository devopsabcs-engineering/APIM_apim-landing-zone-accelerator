<!-- markdownlint-disable-file -->
# Release Changes: APIops GitHub Workflows Migration

**Related Plan**: apiops-github-workflows-plan.instructions.md
**Implementation Date**: 2026-03-19

## Summary

Convert 6 Azure DevOps APIops pipelines (3 extractors + 3 publishers) to GitHub Actions workflows using apiops v6.0.2, matching the multi-team structure (general, api-team-001, api-team-002) with dev and prod APIM environment support.

## Changes

### Added

* `.github/workflows/run-extractor.api-team-001.yaml` - New team-001 scoped extractor workflow with fixed config (`configuration.extractor.dev-005.api-team-001.yaml`) and output folder (`artifacts.dev-005.api-team-001`), using apiops v6.0.2, Spectral linting, and PR creation via `peter-evans/create-pull-request@v6`
* `.github/workflows/run-extractor.api-team-002.yaml` - New team-002 scoped extractor workflow with fixed config (`configuration.extractor.dev-005.api-team-002.yaml`) and output folder (`artifacts.dev-005.api-team-002`), using apiops v6.0.2, Spectral linting, and PR creation via `peter-evans/create-pull-request@v6`
* `.github/workflows/run-publisher.api-team-001.yaml` - New team-001 publisher workflow with auto-trigger on push to `main` when `artifacts.dev-005.api-team-001/**` changes, calling reusable workflow for dev then prod stages
* `.github/workflows/run-publisher.api-team-002.yaml` - New team-002 publisher workflow with auto-trigger on push to `main` when `artifacts.dev-005.api-team-002/**` changes, calling reusable workflow for dev then prod stages

### Modified

* `.github/workflows/run-publisher-with-env.yaml` - Upgraded apiops from v4.1.2 to v6.0.2, switched to zip-based download with `Expand-Archive`, removed Spectral lint steps, upgraded `actions/checkout@v3` to `@v4`, upgraded `cschleiden/replace-tokens@v1.1` to `@v1.3`, hardcoded `configuration.prod-005.yaml` in token replacement
* `.github/workflows/run-extractor.yaml` - Full rewrite: upgraded to v6.0.2 with zip download, added selectable output folder (4 options including backward-compatible `artifacts`), added 5 config file options, added Spectral linting, upgraded to `actions/checkout@v4`, `upload-artifact@v4`, `create-pull-request@v6`, consolidated to single-job workflow
* `.github/workflows/run-publisher.yaml` - Rewritten with multi-folder artifact selection (4 options, default `artifacts.dev-005`), modernized `set-output` to `$GITHUB_OUTPUT`, updated prod config path to `configuration.prod-005.yaml`, uses dynamic folder in reusable workflow calls

### Removed

* Spectral lint steps from `run-publisher-with-env.yaml` (moved to extractor workflows)
* Old `actions/download-artifact@v2` and separate `create-pull-request` job from `run-extractor.yaml` (consolidated into single job)

## Additional or Deviating Changes

* Token replacement file pattern in `run-publisher-with-env.yaml` hardcoded to `configuration.prod-005.yaml` instead of using dynamic `format()` function
  * The actual prod config file uses the `-005` suffix which doesn't match the environment name `prod`, so the dynamic pattern `configuration.prod.yaml` would not match
* General publisher (`run-publisher.yaml`) retains `pull_request: closed` trigger for backward compatibility; team-specific publishers use `push` trigger with path filters instead
  * ADO team publishers use path triggers on their artifact folders; GitHub Actions `push` + `paths` filter is the equivalent

## Release Summary

Total files affected: 7 (4 added, 3 modified)

**Files created:**
* `.github/workflows/run-extractor.api-team-001.yaml` - Team-001 extractor
* `.github/workflows/run-extractor.api-team-002.yaml` - Team-002 extractor
* `.github/workflows/run-publisher.api-team-001.yaml` - Team-001 publisher with path trigger
* `.github/workflows/run-publisher.api-team-002.yaml` - Team-002 publisher with path trigger

**Files modified:**
* `.github/workflows/run-publisher-with-env.yaml` - Reusable publisher foundation (v6.0.2 upgrade)
* `.github/workflows/run-extractor.yaml` - General extractor (v6.0.2 upgrade + multi-folder)
* `.github/workflows/run-publisher.yaml` - General publisher (multi-folder + modernized)

**Dependencies:** All workflows require GitHub environments `dev` and `prod` configured with secrets `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and variables `AZURE_RESOURCE_GROUP_NAME`, `API_MANAGEMENT_SERVICE_NAME`.

**Deployment notes:** No infrastructure changes required. Workflow files deploy to `.github/workflows/` and are activated automatically by GitHub Actions. Ensure GitHub environments and secrets are configured before running workflows.
