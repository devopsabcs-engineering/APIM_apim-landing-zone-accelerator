---
applyTo: '.copilot-tracking/changes/2026-03-21/apim-on-demand-lab-changes.md'
---
<!-- markdownlint-disable-file -->
# Implementation Plan: APIM On-Demand Lab — Phase 2 & 3

## Overview

Implement migration automation (Phase 2) and single-click lab provisioning (Phase 3) to enable on-demand creation and teardown of the complete APIM demo environment with all 9 backend APIs.

## Objectives

### User Requirements

* Automate the migration gaps discovered when publishing v1 artifacts to BasicV2 — Source: conversation and research document
* Create a single-click lab provisioning workflow — Source: user request for "click of a button" environment
* Enable cost savings through on-demand teardown and recreation — Source: user request
* Document the process so customers can learn APIops best practices — Source: user request

### Derived Objectives

* Create artifact sanitizer to prevent future v1-to-v2 publishing failures — Derived from: 8 migration gaps repeatedly fixed manually
* Add APIM post-deployment configuration via Azure CLI — Derived from: OAuth2 servers, identity providers, users cannot be managed via APIops
* Build master orchestrator workflow chaining existing workflows — Derived from: current setup requires 3 manual workflow dispatches

## Context Summary

### Project Files

* `.copilot-tracking/research/2026-03-21/apim-documentation-roadmap-research.md` — Phase 2-4 roadmap and migration gap analysis
* `docs/roadmap.md` — 5-phase roadmap with metrics
* `docs/on-demand-lab.md` — Current manual runbook (3 steps to create, 2 to teardown)
* `docs/migration-v1-to-basicv2.md` — Migration lessons learned

### References

* `infra/api-management-basicv2/main.bicep` — Current BasicV2 Bicep template (no OAuth2, no AAD provider)
* `.github/workflows/deploy-apim-basicv2.yml` — APIM infrastructure deployment
* `.github/workflows/deploy-all.yml` — Backend API deployment orchestrator
* `.github/workflows/run-publisher-006.yaml` — APIops publisher

### Standards References

* #file:../../.github/instructions/ado-workflow.instructions.md — ADO work item tracking conventions

## Implementation Checklist

### [ ] Implementation Phase 1: Artifact Sanitizer Script

<!-- parallelizable: true -->

* [ ] Step 1.1: Create PowerShell script `scripts/sanitize-artifacts-for-v2.ps1`
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 10-45)
* [ ] Step 1.2: Integrate sanitizer into publisher-with-env-006.yaml as pre-publish step
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 47-65)
* [ ] Step 1.3: Validate by running publisher 006 workflow
  * Skip if validation conflicts with parallel phases

### [ ] Implementation Phase 2: APIM Post-Deployment Configuration

<!-- parallelizable: true -->

* [ ] Step 2.1: Add OAuth2 authorization server to BasicV2 Bicep template
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 70-100)
* [ ] Step 2.2: Add Azure CLI post-deploy step for AAD identity provider
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 102-125)
* [ ] Step 2.3: Create demo user and subscription seeding script
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 127-160)
* [ ] Step 2.4: Integrate into deploy-apim-basicv2.yml as post-deploy steps
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 162-180)

### [ ] Implementation Phase 3: Master Orchestrator Workflow

<!-- parallelizable: false -->

* [ ] Step 3.1: Create `create-lab.yml` workflow that chains APIM + APIs + APIops
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 185-230)
* [ ] Step 3.2: Create `teardown-lab.yml` workflow with confirmation gate
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 232-260)
* [ ] Step 3.3: Add deployment time tracking and cost estimation to summaries
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 262-285)

### [ ] Implementation Phase 4: Migration Validation Workflow

<!-- parallelizable: true -->

* [ ] Step 4.1: Create `validate-artifacts.yml` pre-publish check workflow
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 290-320)
* [ ] Step 4.2: Add validation step to publisher 006 workflow before actual publish
  * Details: .copilot-tracking/details/2026-03-21/apim-on-demand-lab-details.md (Lines 322-340)

### [ ] Implementation Phase 5: Validation

<!-- parallelizable: false -->

* [ ] Step 5.1: Run full lab create workflow end-to-end
  * Execute create-lab.yml and verify all components deploy
  * Check APIM developer portal shows all APIs
  * Verify wiki deployment report generated
* [ ] Step 5.2: Run full tear down
  * Execute teardown-lab.yml and verify all resource groups deleted
* [ ] Step 5.3: Report blocking issues
  * Document issues requiring additional research
  * Provide next steps for Phase 4 (DR, Premium SKU demos)

## Planning Log

See [apim-on-demand-lab-log.md](.copilot-tracking/plans/logs/2026-03-21/apim-on-demand-lab-log.md) for discrepancy tracking, implementation paths considered, and suggested follow-on work.

## Dependencies

* Azure CLI 2.84+ (installed on GitHub Actions runners)
* APIops v6.0.2 extractor/publisher binaries
* Puppeteer (for screenshot capture in smoke tests)
* GitHub Wiki enabled on the repository
* GitHub Environments configured with OIDC secrets

## Success Criteria

* Single workflow creates APIM + 9 APIs + API configurations in < 30 minutes — Traces to: user requirement for "click of a button"
* Single workflow tears down all resources — Traces to: cost savings requirement
* Publisher 006 succeeds without manual artifact fixups — Traces to: migration automation gaps
* OAuth2 servers and AAD provider created automatically — Traces to: migration gap #1 and #2
* Demo users and subscriptions seeded automatically — Traces to: migration gap #4
