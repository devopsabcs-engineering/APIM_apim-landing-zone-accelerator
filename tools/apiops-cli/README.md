# APIops CLI tooling (APIM 007)

Locked tooling for the dev-007/prod-007 promotion workflows. Workflows run the local executable from this folder; they never download the CLI on the fly or use a global install.

## Pin

* Package: `@azure-tools/apiops-cli` exactly `1.0.4` (sha512 `integrity` for all 55 packages in `package-lock.json`).
* Node: 22 (`.nvmrc`, `engines: >=22 <23`). `engine-strict` is not set.
* Registry: `.npmrc` points at the anonymous 1ES public Azure Artifacts proxy feed (`ms-feed-25.pkgs.visualstudio.com/1es-public/_packaging/npm-public`), the same pattern as the sibling `ai-sdlc-practice` repository. The lockfile `resolved` URLs use that feed, so local installs work behind the corporate network and GitHub runners download from the same feed.

## Install and check

```powershell
npm ci --ignore-scripts
node node_modules/@azure-tools/apiops-cli/dist/cli/index.js --version   # 1.0.4
```

On Linux runners use `node_modules/.bin/apiops --version`. Install before `azure/login`.

## Review findings (2026-10-06)

* Lifecycle scripts: `npm query` for `preinstall`, `install`, `postinstall` and `prepare` returned none across all 55 packages. Always install with `--ignore-scripts`.
* Provenance: the feed publishes only sha1 for most packages and `npm audit signatures` does not support it. The lockfile records sha512 computed from the feed tarballs after verifying each against the feed sha1. Every workflow install runs `scripts/apim-007/Test-Apim007LockfileProvenance.ps1` first, which fails unless each sha512 equals the `dist.integrity` published on registry.npmjs.org; `npm ci` then enforces the same hashes on download.
* `npm audit`: 3 critical advisories through `simple-git` (`@simple-git/argv-parser` GHSA-v5rq-49vh-5v5c, `VISUAL` editor variable), no fix available. The 007 workflows always run full publishes (no incremental commit selection) and do not set editor variables; reassess when a fixed release exists.

## Upgrade procedure

1. Revalidate research contract items C1-C9 (`.copilot-tracking/research/2026-10-06/dev-007-apiops-cli-research.md`) against the new version's source before changing the pin.
2. Change the exact version in `package.json`, regenerate with `npm install --package-lock-only --ignore-scripts` (uses the feed from `.npmrc`), upgrade any sha1 `integrity` entries to sha512 from the downloaded tarballs, then rerun the lifecycle, provenance and audit checks above.
3. Update this file with the new version and findings, and run the 007 PR validation workflow.
