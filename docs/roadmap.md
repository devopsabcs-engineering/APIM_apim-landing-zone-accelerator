# Roadmap

## Vision

Build an on-demand APIM lab environment that teaches customers APIops best practices, demonstrates enterprise API management patterns, and can be created and torn down at the click of a button.

## Phase 1: Foundation (Completed)

- [x] Migrate APIops pipelines from Azure DevOps to GitHub Actions
- [x] Split extractors and publishers by API team (001, 002)
- [x] Deploy APIM BasicV2 dev and prod instances (instance 006)
- [x] Deploy 9 backend APIs with Docker containers and zip deployment
- [x] Add version endpoints to all APIs
- [x] Enhanced smoke tests with screenshots (Puppeteer)
- [x] GitHub Wiki deployment reports
- [x] Publish API configurations via APIops publisher
- [x] Path-scoped publisher triggers (005 and 006 don't cross-trigger)
- [x] Environment-specific OIDC credentials for APIM deployment

## Phase 2: Migration Automation (Next)

- [ ] **OAuth2 authorization server** — Script creation via Azure CLI or Bicep
- [ ] **AAD identity provider** — Automate setup in APIM Bicep template
- [ ] **User seeding** — Script to create demo users in fresh APIM instances
- [ ] **Subscription seeding** — Automate product subscription creation
- [ ] **Migration validation** — Pre-publish workflow that validates artifacts against target APIM
- [ ] **Artifact sanitizer** — Script to clean 005-specific references when copying to 006

## Phase 3: Single-Click Lab (Future)

- [ ] **Master orchestrator workflow** — Single `create-lab.yml` that chains APIM deploy → API deploy → APIops publish
- [ ] **Tear down orchestrator** — Single workflow to destroy everything
- [ ] **Cost tracking** — Integrate with Azure Cost Management to report lab costs per run
- [ ] **Provisioning dashboard** — GitHub Pages site showing current lab status

## Phase 4: Advanced Demonstrations (Future)

- [ ] **Disaster Recovery** — Deploy to a second Azure region, demonstrate failover
- [ ] **StandardV2 SKU** — Short-term deployment to demo VNet integration with APIM v2
- [ ] **Premium SKU** — Short-term deployment to demo workspaces when available in Canada
- [ ] **Workspace gateway demos** — Show how API teams operate independently
- [ ] **Multi-region** — Premium multi-region deployment for global API management

## Phase 5: Customer Training (Future)

- [ ] **Interactive lab guide** — Step-by-step walkthrough for customers
- [ ] **Scenario-based exercises** — "Add a new API", "Manage API teams", "Set up CI/CD"
- [ ] **Assessment tool** — Evaluate customer API management maturity
- [ ] **Reference architecture docs** — Document patterns for different customer scenarios

## SKU Progression Strategy

```text
BasicV2 ($150/mo)          → Day-to-day development and demos
  ↓
StandardV2 ($350/mo)       → VNet integration demos (deploy for hours, tear down)
  ↓
Premium ($2,800+/mo)       → Workspace and multi-region demos (deploy for hours, tear down)
```

The on-demand approach lets us demonstrate Premium-tier features without sustained Premium costs.

## Key Metrics

| Metric | Target |
|--------|--------|
| Full environment deploy time | < 30 minutes |
| Full teardown time | < 15 minutes |
| Monthly cost (always-on BasicV2) | ~$390 |
| Monthly cost (on-demand, 8 hours/week) | ~$40 |
| APIs managed | 15+ |
| API teams supported | 2+ |
