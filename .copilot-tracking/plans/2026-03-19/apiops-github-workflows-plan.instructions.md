---
applyTo: '.copilot-tracking/changes/2026-03-19/apiops-github-workflows-changes.md'
---
<!-- markdownlint-disable-file -->
# Implementation Plan: APIops GitHub Workflows Migration

## Overview

Convert 6 Azure DevOps APIops pipelines (3 extractors + 3 publishers) to GitHub Actions workflows using apiops v6.0.2, matching the multi-team structure (general, api-team-001, api-team-002) with dev and prod APIM environment support.

## Objectives

### User Requirements

* Create 3 GitHub extractor workflows: general, api-team-001, api-team-002 — Source: research document (Lines 6-7)
* Create 3 GitHub publisher workflows: general, api-team-001, api-team-002 — Source: research document (Lines 8-9)
* Reuse existing `run-publisher-with-env.yaml` reusable workflow pattern — Source: research document (Line 10)
* Upgrade existing stale workflows (v4.1.2) to latest stable v6.0.2 — Source: research document (Line 11)
* Include Spectral linting in extractor workflows — Source: research document (Line 12)
* Support both dev (Dev-005) and prod (Prod-005) APIM environments — Source: research document (Line 13)

### Derived Objectives

* Keep GitHub environment names as `dev` and `prod` to maintain compatibility with the reusable workflow's conditional logic — Derived from: `run-publisher-with-env.yaml` uses `inputs.API_MANAGEMENT_ENVIRONMENT == 'prod'` to gate token replacement
* Upgrade action versions from v2/v3 to current stable (checkout@v4, upload-artifact@v4, setup-node@v4) — Derived from: existing workflows use deprecated action versions
* Switch from bare executable download to zip-based download pattern matching apiops v6.0.2 release format — Derived from: v6.0.2 ships as zip archives, not bare executables
* Replace `cschleiden/replace-tokens@v1.1` with `cschleiden/replace-tokens@v1.3` for token substitution — Derived from: research mapping table
* Use `peter-evans/create-pull-request@v6` for PR creation in extractors instead of ADO `az repos pr create` — Derived from: GitHub Actions equivalent for PR auto-creation
* Add `workflow_dispatch` triggers to all workflows plus `push` triggers on team-specific publisher workflows — Derived from: ADO pipeline trigger parity

## Context Summary

### Project Files

* `.github/workflows/run-extractor.yaml` - Existing general extractor, v4.1.2, stale, outputs to `artifacts/` folder
* `.github/workflows/run-publisher.yaml` - Existing general publisher, stale, triggers on PR close to main
* `.github/workflows/run-publisher-with-env.yaml` - Existing reusable publisher workflow, v4.1.2, 4 conditional publisher steps
* `tools/azdo_pipelines/run-extractor.yaml` - ADO general extractor pipeline, v6.0.2 zip pattern, Spectral + PR creation
* `tools/azdo_pipelines/run-extractor.api-team-001.yaml` - ADO team-001 extractor, scoped config
* `tools/azdo_pipelines/run-extractor.api-team-002.yaml` - ADO team-002 extractor, scoped config
* `tools/azdo_pipelines/run-publisher.yaml` - ADO general publisher, manual trigger, selectable artifact folder
* `tools/azdo_pipelines/run-publisher.api-team-001.yaml` - ADO team-001 publisher, auto-triggers on `artifacts.dev-005.api-team-001/*`
* `tools/azdo_pipelines/run-publisher.api-team-002.yaml` - ADO team-002 publisher, auto-triggers on `artifacts.dev-005.api-team-002/*`
* `tools/azdo_pipelines/run-publisher-with-env.yaml` - ADO reusable publisher template, token replacement + publisher binary
* `configuration.extractor.dev-005.yaml` - General dev extractor configuration
* `configuration.extractor.dev-005.api-team-001.yaml` - Team-001 extractor configuration
* `configuration.extractor.dev-005.api-team-002.yaml` - Team-002 extractor configuration
* `configuration.prod-005.yaml` - Prod publisher configuration with token placeholders

### References

* `.copilot-tracking/research/2026-03-19/apiops-github-workflows-research.md` - Primary research document

### Standards References

* #file:../../.github/instructions/ado-workflow.instructions.md - ADO workflow conventions for branching, commits, and PRs

## Implementation Checklist

### [ ] Implementation Phase 1: Upgrade Existing Reusable Publisher Workflow

<!-- parallelizable: false -->

* [ ] Step 1.1: Upgrade `run-publisher-with-env.yaml` to v6.0.2 with zip-based download, modern actions, updated token replacement, and explicit `configuration.prod-005.yaml` file pattern
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 1, Step 1.1)
* [ ] Step 1.2: Validate reusable workflow YAML syntax
  * Run `yamllint` or GitHub Actions lint on the modified file

### [ ] Implementation Phase 2: Upgrade and Extend Extractor Workflows

<!-- parallelizable: true -->

* [ ] Step 2.1: Upgrade `run-extractor.yaml` — update to v6.0.2, zip download, add `artifacts.dev-005` output folder option (keep `artifacts` for backward compatibility), add config file choices (keep `configuration.extractor.yaml` for backward compatibility), add Spectral linting, add PR creation via `peter-evans/create-pull-request@v6`, upgrade actions to v4
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 2, Step 2.1)
* [ ] Step 2.2: Create `run-extractor.api-team-001.yaml` — team-001 scoped extractor with fixed config and artifact folder, Spectral linting, PR creation
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 2, Step 2.2)
* [ ] Step 2.3: Create `run-extractor.api-team-002.yaml` — team-002 scoped extractor with fixed config and artifact folder, Spectral linting, PR creation
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 2, Step 2.3)

### [ ] Implementation Phase 3: Upgrade and Extend Publisher Workflows

<!-- parallelizable: true -->

* [ ] Step 3.1: Upgrade `run-publisher.yaml` — update to use `artifacts.dev-005` default folder (keep `artifacts` for backward compatibility), add `artifacts.dev-005.api-team-001` and `artifacts.dev-005.api-team-002` options, use `dev`/`prod` environment names, upgrade to call updated reusable workflow with dev then prod stages
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 3, Step 3.1)
* [ ] Step 3.2: Create `run-publisher.api-team-001.yaml` — auto-trigger on push to main when `artifacts.dev-005.api-team-001/**` changes, calls reusable workflow for dev then prod
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 3, Step 3.2)
* [ ] Step 3.3: Create `run-publisher.api-team-002.yaml` — auto-trigger on push to main when `artifacts.dev-005.api-team-002/**` changes, calls reusable workflow for dev then prod
  * Details: .copilot-tracking/details/2026-03-19/apiops-github-workflows-details.md (Phase 3, Step 3.3)

### [ ] Implementation Phase 4: Validation

<!-- parallelizable: false -->

* [ ] Step 4.1: Validate all 7 workflow YAML files syntax
  * Verify YAML parses correctly for all files in `.github/workflows/`
  * Check all `workflow_call` input references match between caller and callee
* [ ] Step 4.2: Verify cross-workflow references
  * Confirm `run-publisher.yaml`, `run-publisher.api-team-001.yaml`, and `run-publisher.api-team-002.yaml` correctly reference `run-publisher-with-env.yaml`
    * Confirm environment names (`dev`, `prod`) are consistent across all workflows and match the reusable workflow's conditional logic
* [ ] Step 4.3: Verify artifact folder paths
  * Confirm extractor output paths match publisher input paths for each team scope
  * Verify configuration file references exist in the repo root
* [ ] Step 4.4: Document any blocking issues
  * Report issues requiring GitHub environment/secret setup
  * Provide user with next steps for runtime validation

## Planning Log

See [apiops-github-workflows-log.md](../../plans/logs/2026-03-19/apiops-github-workflows-log.md) for discrepancy tracking, implementation paths considered, and suggested follow-on work.

## Dependencies

* GitHub Actions runner (`ubuntu-latest`)
* apiops v6.0.2 release binaries (extractor + publisher zip archives)
* `peter-evans/create-pull-request@v6` action for PR creation in extractors
* `cschleiden/replace-tokens@v1.3` action for token substitution in publisher
* `actions/checkout@v4`, `actions/upload-artifact@v4`, `actions/setup-node@v4` (modern action versions)
* `@stoplight/spectral-cli` npm package for API linting
* GitHub environments: `dev` and `prod` with required secrets/variables configured
* Service principal with `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` stored as environment secrets

## Success Criteria

* All 7 workflow files parse as valid GitHub Actions YAML — Traces to: user requirement for 6 workflows + 1 reusable
* All extractor workflows download apiops v6.0.2 zip, extract, and run the extractor binary — Traces to: upgrade requirement
* All extractor workflows include Spectral linting step — Traces to: user requirement for Spectral
* All extractor workflows create PRs via `peter-evans/create-pull-request@v6` — Traces to: ADO PR creation parity
* General publisher supports manual dispatch with selectable artifact folder (including backward-compatible `artifacts` option) — Traces to: ADO publisher parity
* Team-specific publishers auto-trigger on push to main when their artifact folder changes — Traces to: ADO path trigger parity
* All publishers call `run-publisher-with-env.yaml` reusable workflow for dev then prod stages using `dev`/`prod` environment names — Traces to: reusable workflow requirement
* Token substitution in `configuration.prod-005.yaml` works via `cschleiden/replace-tokens@v1.3` with hardcoded file pattern — Traces to: ADO replacetokens parity
