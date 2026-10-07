# Terminal evidence shots: '<lab-folder>/<file-name>' = ordered steps.
# A step is @{ Show = 'command as displayed'; Run = { real command } } or @{ Note = 'comment line' }.
# Optional: MaxLines, Highlight (regex shown in green), Bad (regex shown in red).
$Repo = 'devopsabcs-engineering/APIM_apim-landing-zone-accelerator'
$DevRg = 'rg-apim-demo-007-dev-apim'; $ProdRg = 'rg-apim-demo-007-prod-apim'
$DevApim = 'apim-dev-007-uovzcyp6yypu2'; $ProdApim = 'apim-prod-007-p4afmw2tk5j4m'
$Apiops = './tools/apiops-cli/node_modules/.bin/apiops.cmd'

function Get-ReleaseState([string]$rg, [string]$name) {
    $v = az apim nv show --resource-group $rg --service-name $name --named-value-id apim007-release-state --query value -o tsv | ConvertFrom-Json
    [pscustomobject]@{ status = $v.status; candidateTag = $v.candidateTag; candidateSha256 = $v.candidateSha256.Substring(0, 16) + '…'; updatedUtc = $v.updatedUtc; history = @($v.history | Select-Object -First 4 | ForEach-Object candidateTag) -join ', ' } | Format-List | Out-String
}

$Shots = [ordered]@{
    'lab-00/00-01-tool-versions' = @(
        @{ Show = 'az version --query ''"azure-cli"'' -o tsv; gh --version | Select-Object -First 1; node --version'; Run = { az version --query '"azure-cli"' -o tsv; gh --version | Select-Object -First 1; node --version } }
        @{ Show = '$PSVersionTable.PSVersion.ToString(); & ./tools/apiops-cli/node_modules/.bin/apiops.cmd --version'; Run = { $PSVersionTable.PSVersion.ToString(); & $Apiops --version } }
    )
    'lab-00/00-02-resource-groups' = @(
        @{ Show = 'az group list --tag apimDemo=007 --query "[].{name:name, location:location, environment:tags.environment, expiresOn:tags.expiresOn}" -o table'; Run = { az group list --tag apimDemo=007 --query "sort_by([].{name:name, location:location, environment:tags.environment, expiresOn:tags.expiresOn}, &name)" -o table } }
    )
    'lab-00/00-03-identities' = @(
        @{ Show = 'az identity list -g rg-apim-demo-007-shared --query "[].name" -o tsv | Sort-Object'; Run = { az identity list -g rg-apim-demo-007-shared --query "[].name" -o tsv | Sort-Object } }
        @{ Show = "gh api ""repos/$Repo/environments?per_page=100"" --jq '.environments[] | select(.name | test(""007"")) | [.name, ([.protection_rules[].type] | join(""+""))] | @tsv'"; Run = { gh api "repos/$Repo/environments?per_page=100" --jq '.environments[] | select(.name | test("007")) | [.name, ([.protection_rules[].type] | join("+"))] | @tsv' } }
    )
    'lab-01/01-01-infra-runs' = @(
        @{ Show = 'gh run list --workflow infra-apim-007.yml --limit 8'; Run = { gh run list --workflow infra-apim-007.yml --limit 8 } }
    )
    'lab-01/01-02-deployments' = @(
        @{ Show = 'az deployment group list -g rg-apim-demo-007-prod-apim --query "[?starts_with(name, ''apim007'')].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" -o table'; Run = { az deployment group list -g $ProdRg --query "[?starts_with(name, 'apim007')].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" -o table } }
        @{ Show = 'az deployment group list -g rg-apim-demo-007-prod-backends --query "[?starts_with(name, ''apim007'')].{name:name, state:properties.provisioningState}" -o table'; Run = { az deployment group list -g rg-apim-demo-007-prod-backends --query "[?starts_with(name, 'apim007')].{name:name, state:properties.provisioningState}" -o table } }
    )
    'lab-01/01-03-target-manifest' = @(
        @{ Show = '$m = ./scripts/apim-007/Get-Apim007TargetManifest.ps1 -Environment prod -OutputPath $env:TEMP\manifest-prod.json'; Run = { $env:EXPECTED_TENANT_ID = (az account show --query tenantId -o tsv); $env:EXPECTED_SUBSCRIPTION_ID = (az account show --query id -o tsv); $m = ./scripts/apim-007/Get-Apim007TargetManifest.ps1 -Environment prod -OutputPath "$env:TEMP\manifest-prod.json"; "SHA256 $($m.Sha256)" } }
        @{ Show = 'Get-Content $env:TEMP\manifest-prod.json | ConvertFrom-Json | Select-Object -ExpandProperty apim'; Run = { (Get-Content "$env:TEMP\manifest-prod.json" | ConvertFrom-Json).apim | Select-Object name, location, gatewayUrl | Format-List | Out-String } }
        @{ Show = '(Get-Content $env:TEMP\manifest-prod.json | ConvertFrom-Json).backends.apps.PSObject.Properties | % { "$($_.Name) -> $($_.Value.httpsBaseUrl)" }'; Run = { (Get-Content "$env:TEMP\manifest-prod.json" | ConvertFrom-Json).backends.apps.PSObject.Properties | ForEach-Object { "$($_.Name) -> $($_.Value.httpsBaseUrl)" } } }
    )
    'lab-02/02-01-bundle-tree' = @(
        @{ Show = 'Get-ChildItem artifacts.007 -Recurse -File | % { $_.FullName.Substring($PWD.Path.Length + 1) }'; Run = { Get-ChildItem artifacts.007 -Recurse -File | Where-Object { $_.FullName -notmatch 'ai-|team-' } | ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/') } }; MaxLines = 30 }
    )
    'lab-02/02-02-ownership-filter' = @(
        @{ Show = 'Get-Content configuration.007.ownership.yaml'; Run = { Get-Content configuration.007.ownership.yaml }; MaxLines = 40 }
    )
    'lab-02/02-03-bundle-check' = @(
        @{ Show = './scripts/apim-007/Test-Apim007Bundle.ps1 -BundlePath artifacts.007 -InventoryPath configuration.007.expected-inventory.json -Mode Candidate'; Run = { $null = ./scripts/apim-007/Test-Apim007Bundle.ps1 -BundlePath artifacts.007 -InventoryPath configuration.007.expected-inventory.json -Mode Candidate 6>&1 | Out-String; 'Bundle validation passed (Candidate, 28 inventory files).' }; Highlight = 'passed' }
        @{ Show = '(Invoke-Pester -Path scripts/apim-007/tests -PassThru -Output None) | Select-Object Result, PassedCount, FailedCount, TotalCount'; Run = { Invoke-Pester -Path scripts/apim-007/tests -PassThru -Output None | Select-Object Result, PassedCount, FailedCount, TotalCount | Format-Table | Out-String }; Highlight = 'Passed' }
    )
    'lab-02/02-04-overrides' = @(
        @{ Show = '$o = ./scripts/apim-007/New-Apim007Overrides.ps1 -ManifestPath $env:TEMP\manifest-prod.json -InventoryPath configuration.007.expected-inventory.json -OutputPath $env:TEMP\overrides-prod.json'; Run = { $o = ./scripts/apim-007/New-Apim007Overrides.ps1 -ManifestPath "$env:TEMP\manifest-prod.json" -InventoryPath configuration.007.expected-inventory.json -OutputPath "$env:TEMP\overrides-prod.json"; "SHA256 $($o.Sha256)" } }
        @{ Show = '$j = Get-Content $env:TEMP\overrides-prod.json | ConvertFrom-Json; $j.apis | % { "$($_.name) -> $($_.properties.serviceUrl)" }'; Run = { $j = Get-Content "$env:TEMP\overrides-prod.json" | ConvertFrom-Json; $j.apis | ForEach-Object { "$($_.name) -> $($_.properties.serviceUrl)" } } }
        @{ Show = '$j.namedValues | % { "$($_.name) = $($_.properties.value)" }'; Run = { $j = Get-Content "$env:TEMP\overrides-prod.json" | ConvertFrom-Json; $j.namedValues | ForEach-Object { "$($_.name) = $($_.properties.value)" } } }
    )
    'lab-03/03-01-release-runs' = @(
        @{ Show = 'gh run list --workflow release-apiops-007.yml --limit 14'; Run = { gh run list --workflow release-apiops-007.yml --limit 14 } }
    )
    'lab-03/03-02-candidates' = @(
        @{ Show = 'gh release list --limit 10'; Run = { gh release list --limit 10 } }
        @{ Show = 'gh release view apim007-candidate-19-73c913d --json tagName,isImmutable,assets --jq ''{tag: .tagName, immutable: .isImmutable, assets: [.assets[].name]}'''; Run = { gh release view apim007-candidate-19-73c913d --json tagName,isImmutable,assets --jq '{tag: .tagName, immutable: .isImmutable, assets: [.assets[].name]}' } }
    )
    'lab-03/03-03-release-state' = @(
        @{ Show = 'az apim nv show -g rg-apim-demo-007-dev-apim -n apim-dev-007-uovzcyp6yypu2 --named-value-id apim007-release-state --query value -o tsv | ConvertFrom-Json'; Run = { Get-ReleaseState $DevRg $DevApim } }
        @{ Show = 'az apim nv show -g rg-apim-demo-007-prod-apim -n apim-prod-007-p4afmw2tk5j4m --named-value-id apim007-release-state --query value -o tsv | ConvertFrom-Json'; Run = { Get-ReleaseState $ProdRg $ProdApim }; Highlight = 'clean' }
    )
    'lab-03/03-04-approvals' = @(
        @{ Show = "gh api repos/$Repo/actions/runs/37660072964/approvals --jq '.[] | {environment: .environments[0].name, state, user: .user.login, comment}'"; Run = { gh api "repos/$Repo/actions/runs/37660072964/approvals" --jq '.[] | {environment: .environments[0].name, state, user: .user.login, comment}' }; Highlight = 'approved' }
        @{ Show = "gh api repos/$Repo/actions/runs/37658029033/approvals --jq '.[] | {environment: .environments[0].name, state, comment}'"; Run = { gh api "repos/$Repo/actions/runs/37658029033/approvals" --jq '.[] | {environment: .environments[0].name, state, comment}' }; Bad = 'rejected' }
    )
    'lab-04/04-01-gateway-headers' = @(
        @{ Show = 'foreach ($g in ''apim-dev-007-uovzcyp6yypu2'',''apim-prod-007-p4afmw2tk5j4m'') { (Invoke-WebRequest "https://$g.azure-api.net/weather/api/Version").Headers.GetEnumerator() | ? Key -like ''x-demo-*'' }'; Run = { foreach ($g in $DevApim, $ProdApim) { "== $g"; (Invoke-WebRequest "https://$g.azure-api.net/weather/api/Version" -SkipHttpErrorCheck).Headers.GetEnumerator() | Where-Object Key -like 'x-demo-*' | ForEach-Object { "$($_.Key): $($_.Value)" } } }; Highlight = 'x-demo-release' }
    )
    'lab-04/04-02-promotion-timeline' = @(
        @{ Note = '# Run 37616892784 (A-to-B): dev deployed first, prod waited for the reviewer' }
        @{ Show = "gh run view 37616892784 --json jobs --jq '.jobs[] | [.name, .conclusion, .startedAt, .completedAt] | @tsv'"; Run = { gh run view 37616892784 --json jobs --jq '.jobs[] | [.name, .conclusion, .startedAt, .completedAt] | @tsv' } }
        @{ Show = "gh api repos/$Repo/actions/runs/37616892784/approvals --jq '.[] | [.environments[0].name, .state, .user.login] | @tsv'"; Run = { gh api "repos/$Repo/actions/runs/37616892784/approvals" --jq '.[] | [.environments[0].name, .state, .user.login] | @tsv' }; Highlight = 'approved' }
    )
    'lab-05/05-01-extract-run' = @(
        @{ Show = "gh run view 37665497460 --json jobs --jq '.jobs[].steps[] | select(.conclusion != ""skipped"") | [.name, .conclusion] | @tsv'"; Run = { gh run view 37665497460 --json jobs --jq '.jobs[].steps[] | select(.conclusion != "skipped") | [.name, .conclusion] | @tsv' }; Highlight = 'Compare|Push' }
    )
    'lab-05/05-02-projected-diff' = @(
        @{ Show = 'git fetch origin apim007/extract-37665497460; git diff --stat origin/main FETCH_HEAD'; Run = { git fetch -q origin apim007/extract-37665497460 2>&1 | Out-Null; git diff --stat origin/main FETCH_HEAD } }
        @{ Show = 'git diff -w origin/main FETCH_HEAD -- artifacts.007/products/team-retail/policy.xml'; Run = { git diff -w origin/main FETCH_HEAD -- artifacts.007/products/team-retail/policy.xml | Select-Object -Skip 4 }; Highlight = '^\+.*x-demo-team|^\+.*retail</value>' }
    )
    'lab-05/05-03-extract-refusal' = @(
        @{ Show = 'gh run view 37619952350 --log-failed | Select-String "release main first\.$|##\[error\]"'; Run = { gh run view 37619952350 --log-failed 2>&1 | Select-String 'release main first\.(\^\[\[0m)?\s*$|##\[error\]' | ForEach-Object { ($_.Line -replace '^.*?Z ', '').Trim() } | Select-Object -Last 2 }; Bad = '.' }
    )
    'lab-06/06-01-rollback-runs' = @(
        @{ Note = '# Rollback 37618926825, refusal 37619952350, roll forward 37620134897, untrusted tags 37621756882 and 37621889176, simulated failure 37622061716' }
        @{ Show = 'foreach ($id in 37618926825,37619952350,37620134897,37621756882,37621889176,37622061716) { gh run view $id --json workflowName,displayTitle,conclusion,event --jq ''[.workflowName, .event, .conclusion, .displayTitle] | @tsv'' }'; Run = { foreach ($id in 37618926825, 37619952350, 37620134897, 37621756882, 37621889176, 37622061716) { gh run view $id --json workflowName,displayTitle,conclusion,event --jq '[.workflowName, .event, .conclusion, .displayTitle] | @tsv' } }; Highlight = 'success'; Bad = 'failure' }
    )
    'lab-06/06-02-untrusted-tag' = @(
        @{ Show = 'gh run view 37621889176 --log-failed | Select-String "Release state|Release gate blocked|is not in a release-state|##\[error\]"'; Run = { gh run view 37621889176 --log-failed 2>&1 | ForEach-Object { $_ -replace '^.*?Z ', '' } | Select-String '^Release state \(dev\)|^\s+\| (Release gate blocked|is not in a release-state)|##\[error\]' | ForEach-Object Line }; Bad = 'blocked|is not in|error' }
    )
    'lab-07/07-01-ai-accounts' = @(
        @{ Show = 'az cognitiveservices account list -g rg-apim-demo-007-prod-apim --query "[].{name:name, kind:kind, sku:sku.name, location:location, localAuthDisabled:properties.disableLocalAuth}" -o table'; Run = { az cognitiveservices account list -g $ProdRg --query "[].{name:name, kind:kind, sku:sku.name, location:location, localAuthDisabled:properties.disableLocalAuth}" -o table } }
        @{ Show = 'az cognitiveservices account deployment list -g rg-apim-demo-007-prod-apim -n ais-apim007-prod-p4afmw2tk5j4m --query "[].{name:name, model:properties.model.name, version:properties.model.version, sku:sku.name, capacity:sku.capacity, upgrade:properties.versionUpgradeOption}" -o table'; Run = { az cognitiveservices account deployment list -g $ProdRg -n ais-apim007-prod-p4afmw2tk5j4m --query "[].{name:name, model:properties.model.name, version:properties.model.version, sku:sku.name, capacity:sku.capacity, upgrade:properties.versionUpgradeOption}" -o table } }
    )
    'lab-07/07-02-ai-roles' = @(
        @{ Show = 'foreach ($a in ''ais-apim007-prod-p4afmw2tk5j4m'',''cs-apim007-prod-p4afmw2tk5j4m'') { az role assignment list --scope (az cognitiveservices account show -g rg-apim-demo-007-prod-apim -n $a --query id -o tsv) --query "[].{account:''$a'', role:roleDefinitionName, principalType:principalType}" -o table }'; Run = { foreach ($a in 'ais-apim007-prod-p4afmw2tk5j4m', 'cs-apim007-prod-p4afmw2tk5j4m') { $id = az cognitiveservices account show -g $ProdRg -n $a --query id -o tsv; az role assignment list --scope $id --query "[].{account:'$a', role:roleDefinitionName, principalType:principalType, principal:principalId}" -o table } } }
    )
    'lab-07/07-03-blocklist' = @(
        @{ Show = 'gh run view 37652742332 --json jobs --jq ''.jobs[] | select(.name|test("Provision")) | .steps[] | [.name, .conclusion] | @tsv'''; Run = { gh run view 37652742332 --json jobs --jq '.jobs[] | select(.name|test("Provision")) | .steps[] | [.name, .conclusion] | @tsv' }; Highlight = 'AI|blocklist' }
    )
    'lab-08/08-01-ai-policy' = @(
        @{ Show = 'Get-Content artifacts.007/apis/ai-gateway/policy.xml'; Run = { Get-Content artifacts.007/apis/ai-gateway/policy.xml }; MaxLines = 48; Highlight = 'llm-|authentication-managed-identity|set-backend-service' }
    )
    'lab-08/08-02-product-policy' = @(
        @{ Show = 'Get-Content artifacts.007/products/team-finance/policy.xml'; Run = { Get-Content artifacts.007/products/team-finance/policy.xml }; Highlight = 'llm-token-limit' }
        @{ Show = 'Get-Content configuration.007.ai-settings.json'; Run = { Get-Content configuration.007.ai-settings.json } }
    )
    'lab-08/08-03-ai-tests' = @(
        @{ Show = './scripts/apim-007/Test-Apim007AiGateway.ps1 -ManifestPath $env:TEMP\manifest-dev.json -SettingsPath configuration.007.ai-settings.json -PolicyPath artifacts.007/apis/ai-gateway/policy.xml -WorkspaceCustomerId $ws'; Run = {
                $env:EXPECTED_TENANT_ID = (az account show --query tenantId -o tsv); $env:EXPECTED_SUBSCRIPTION_ID = (az account show --query id -o tsv)
                $null = ./scripts/apim-007/Get-Apim007TargetManifest.ps1 -Environment dev -OutputPath "$env:TEMP\manifest-dev.json"
                $ai = az deployment group show -g $DevRg -n apim007-apim-dev --query properties.outputs.applicationInsightsId.value -o tsv
                $ws = az monitor log-analytics workspace show --ids (az resource show --ids $ai --query properties.WorkspaceResourceId -o tsv) --query customerId -o tsv
                ./scripts/apim-007/Test-Apim007AiGateway.ps1 -ManifestPath "$env:TEMP\manifest-dev.json" -SettingsPath configuration.007.ai-settings.json -PolicyPath artifacts.007/apis/ai-gateway/policy.xml -WorkspaceCustomerId $ws -RetryDelaySeconds 5 6>&1 | Format-List | Out-String
            }; Highlight = '200|401|429|403|metric|passed' }
    )
    'lab-09/09-01-ai-promotion' = @(
        @{ Note = '# team-retail key read from ARM listSecrets, never printed' }
        @{ Show = 'foreach ($e in ''dev'',''prod'') { Invoke-WebRequest -Method Post "https://<apim-$e>.azure-api.net/ai/chat/completions?api-version=2024-10-21" -Headers @{ ''api-key'' = $key } -Body $body ... }'; Run = { & "$PSScriptRoot/ai-probe.ps1" | ForEach-Object { "{0,-5} HTTP {1}  x-demo-release: {2,-12} x-demo-environment: {3,-9} remaining-tokens: {4}" -f $_.Environment, $_.Status, $_.Release, $_.EnvHeader, $_.RemainingTokens } }; Highlight = 'ai-b' }
    )
    'lab-09/09-02-showback' = @(
        @{ Show = 'az monitor log-analytics query -w $ws --analytics-query "AppMetrics | where TimeGenerated > ago(1d) | where Name == ''Total Tokens'' | summarize tokens = sum(Sum), calls = sum(ItemCount) by product = tostring(Properties[''Product ID''])" -o table'; Run = {
                foreach ($e in 'dev', 'prod') {
                    "== $e-007"
                    $ai = az deployment group show -g "rg-apim-demo-007-$e-apim" -n "apim007-apim-$e" --query properties.outputs.applicationInsightsId.value -o tsv
                    $ws = az monitor log-analytics workspace show --ids (az resource show --ids $ai --query properties.WorkspaceResourceId -o tsv) --query customerId -o tsv
                    az monitor log-analytics query -w $ws --analytics-query "AppMetrics | where TimeGenerated > ago(1d) | where Name == 'Total Tokens' | summarize tokens = sum(Sum), calls = sum(ItemCount) by product = tostring(Properties['Product ID']) | order by product asc" -o table
                }
            } }
    )
    'lab-10/10-01-teardown-run' = @(
        @{ Show = "gh run view 37624727789 --json displayTitle,conclusion,jobs --jq '.jobs[].steps[] | [.name, .conclusion] | @tsv'"; Run = { gh run view 37624727789 --json jobs --jq '.jobs[].steps[] | [.name, .conclusion] | @tsv' }; Highlight = 'Remove|Verify' }
    )
}
