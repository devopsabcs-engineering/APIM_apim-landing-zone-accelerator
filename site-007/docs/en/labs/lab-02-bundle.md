---
title: "Lab 2: The environment-neutral bundle"
description: Explore the native APIops bundle in artifacts.007, the ownership filter and the expected inventory, then generate per-environment overrides and validate everything locally.
---

# Lab 2: The environment-neutral bundle

<span class="chip phase-plan"><span aria-hidden="true">📦</span> Bundle</span> <span class="chip phase-idea">30 min</span> <span class="chip phase-plan">Intermediate</span>

## Overview

<div class="lab-meta" markdown>

| Item | Details |
|------|---------|
| **Duration** | 30 minutes |
| **Level** | Intermediate |
| **Prerequisites** | [Lab 1](lab-01-infrastructure.md) complete |
| **Checkpoint** | Bundle check and Pester pass locally; dev and prod override files generated |
| **Next lab** | [Lab 3: First release](lab-03-baseline-release.md) |

</div>

The bundle contains **no environment values**. Service URLs, backend hosts and AI limits come from small override files that a script generates from the target manifest at release time.

<figure class="anim-frame" markdown>
![Animated diagram: one environment-neutral bundle plus a dev override file publishes to dev-007, and the same bundle plus a prod override file publishes to prod-007](../../assets/anim/bundle-overrides.svg)
<figcaption>One bundle, two generated override files.</figcaption>
</figure>

## Learning objectives

By the end of this lab, you will be able to:

* Read the APIops CLI native folder layout.
* Explain what the ownership filter protects.
* Generate override files and validate the bundle before you open a pull request.

## Steps

### Step 1: Explore the bundle

```powershell
Get-ChildItem artifacts.007 -Recurse -File | ForEach-Object { $_.FullName.Substring($PWD.Path.Length + 1) }
```

<figure class="screenshot-frame" markdown>
![PowerShell window listing the files under artifacts.007: two APIs with specifications and policies, two backends, one product and one named value](../../assets/img/lab-02/02-01-bundle-tree.png)
<figcaption>The pre-AI bundle: Weather (REST) and SoftwareVersion (SOAP) APIs, their backends, the <code>demo</code> product and one named value.</figcaption>
</figure>

| Folder | Holds |
|--------|-------|
| `apis/<name>/` | `apiInformation.json`, the specification (OpenAPI or WSDL), `policy.xml` |
| `backends/<name>/` | `backendInformation.json` with a sentinel URL replaced by overrides |
| `products/<name>/` | `productInformation.json`, `apis.json`, optional `policy.xml` |
| `namedValues/<name>/` | `namedValueInformation.json` |

### Step 2: Read the ownership filter

```powershell
Get-Content configuration.007.ownership.yaml
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing the YAML ownership filter that lists the owned APIs, backends, products and named values](../../assets/img/lab-02/02-02-ownership-filter.png)
<figcaption>Every publish and extraction runs with <code>--filter</code> and <code>--no-transitive</code>: the pipeline only touches what it owns.</figcaption>
</figure>

!!! gate "Why a filter"
    The APIM service also holds things the pipeline must never change: the Application Insights logger, its instrumentation key, the release-state named value. They are outside the filter, and a fingerprint check fails the release if they change.

### Step 3: Validate the bundle and run the unit tests

```powershell
./scripts/apim-007/Test-Apim007Bundle.ps1 -BundlePath artifacts.007 -InventoryPath configuration.007.expected-inventory.json -Mode Candidate
Invoke-Pester -Path scripts/apim-007/tests -Output Minimal
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing Bundle validation passed for 28 inventory files and Pester Passed with 123 tests](../../assets/img/lab-02/02-03-bundle-check.png)
<figcaption>The same checks run in the pull-request workflow and before every candidate freeze.</figcaption>
</figure>

### Step 4: Generate the prod overrides

```powershell
$o = ./scripts/apim-007/New-Apim007Overrides.ps1 -ManifestPath $env:TEMP\manifest-prod.json `
    -InventoryPath configuration.007.expected-inventory.json -OutputPath $env:TEMP\overrides-prod.json
$j = Get-Content $env:TEMP\overrides-prod.json | ConvertFrom-Json
$j.apis | ForEach-Object { "$($_.name) -> $($_.properties.serviceUrl)" }
```

<figure class="screenshot-frame" markdown>
![PowerShell window showing the overrides SHA256, the prod service URL for each API and the prod values of the AI named values](../../assets/img/lab-02/02-04-overrides.png)
<figcaption>Overrides for prod: each value is checked against a strict pattern, and the file hash is recorded in the plan.</figcaption>
</figure>

### Step 5: Open a pull request

Change something small (for example a policy header) on a branch, push it and open a pull request. `validate-apim-007.yml` runs without any Azure credentials:

<figure class="screenshot-frame" markdown>
![GitHub pull request page with the Validate APIM 007 checks passing: guards, Bicep build, APIops CLI tooling, Pester and bundle validation](../../assets/img/lab-02/02-05-gh-pr-checks.png)
<figcaption>Pull request #30 (the AI bundle) with all validation checks green.</figcaption>
</figure>

!!! checkpoint "Checkpoint"
    `Bundle validation passed`, Pester reports no failures, and `overrides-prod.json` lists prod URLs only.
