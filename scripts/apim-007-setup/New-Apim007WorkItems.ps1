<#
.SYNOPSIS
    Creates or reuses the Azure DevOps work items that track the APIM 007 APIops CLI demo.

.DESCRIPTION
    Creates, in order, an Epic, a Feature under it and five User Stories (S1-S5) under the
    Feature in devopsabcs/OneProject using the az boards commands of the azure-devops
    extension. Every item gets the Area Path, the iteration and the tag required by
    .github/instructions/ado-workflow.instructions.md.

    The script is idempotent: each item is looked up by exact title with WIQL before it is
    created, and parent links are only added when missing. -WhatIf lists the creates and
    links without writing (WIQL lookups and the iteration lookup still run).

    Output: a table of IDs, a JSON ID map (default ./apim007-work-items.json) and the
    suggested branch names feature/<id>-apim007-<suffix>.

    Prerequisites:
      az extension add --name azure-devops
      az login            (or: az devops login --organization <org> with a PAT)

.PARAMETER Organization
    Azure DevOps organization URL.

.PARAMETER Project
    Azure DevOps project.

.PARAMETER AreaPath
    Area Path assigned to every work item.

.PARAMETER IterationPath
    Iteration path. Default: the current iteration of team APIM_DevOps_Team, falling back to the project root.

.PARAMETER Tag
    Tag added to every work item.

.PARAMETER ExistingEpicId
    Reuse this Epic instead of searching for or creating one.

.PARAMETER OutputPath
    Path of the JSON ID map.

.EXAMPLE
    ./New-Apim007WorkItems.ps1 -WhatIf

.EXAMPLE
    ./New-Apim007WorkItems.ps1 -ExistingEpicId 1234
#>
#Requires -Version 7.2
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidatePattern('^https://')]
    [string]$Organization = 'https://dev.azure.com/devopsabcs',

    [ValidateNotNullOrEmpty()]
    [string]$Project = 'OneProject',

    [ValidateNotNullOrEmpty()]
    [string]$AreaPath = 'OneProject\RnD Portfolio\DevOps Program\API Management',

    [string]$IterationPath,

    [ValidateNotNullOrEmpty()]
    [string]$Tag = 'Agentic AI',

    [ValidateRange(1, [int]::MaxValue)]
    [int]$ExistingEpicId,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = './apim007-work-items.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Cmdlet = $PSCmdlet

$Team = 'APIM_DevOps_Team'
$PendingPrefix = '<new:'

#region Work item content

$Epic = @{
    Type        = 'Epic'
    Title       = 'APIOps modernization with APIops CLI'
    Description = '<div>Modernize the APIOps practice of the API Management landing zone with the APIops CLI. The work replaces the legacy extractor and publisher flow with a pinned CLI, environment-neutral native bundles and gated promotion between isolated instances.</div>'
}

$Feature = @{
    Type        = 'Feature'
    Title       = 'dev-007/prod-007 Basic v2 promotion demo with APIops CLI'
    Description = '<div>Build fresh dev-007 and prod-007 API Management Basic v2 instances, isolated from the 005 and 006 instances, and promote one frozen candidate (bundle, scripts and backend image digests) from dev to prod with an approval gate. The demo covers release state, rollback by candidate tag, extraction to a policy-only pull request and teardown.</div>'
}

$Stories = @(
    @{
        Key                = 'S1'
        Suffix             = 'infra'
        Type               = 'User Story'
        Title              = 'APIM 007: isolated infrastructure as code and PR validation'
        Description        = '<div>Create the 007 Bicep templates in infra/apim-demo-007 for API Management Basic v2 without Key Vault, the shared container registry and the per-environment App Service backends. Add the credential-free validate-apim-007.yml pull request workflow so every later story is checked without Azure access.</div>'
        AcceptanceCriteria = '<ul><li>apim.bicep, registry.bicep and backends.bicep build without warnings.</li><li>The APIM 007 template has no Key Vault and no OAuth2 authorization server.</li><li>The registry disables the admin user and anonymous pull; the release principal gets API Management Service Contributor on APIM and Reader on its resource group.</li><li>Backend apps enforce HTTPS only, TLS 1.2, disabled FTP and SCM basic publishing and managed identity registry pulls.</li><li>validate-apim-007.yml runs on pull requests with contents read only, no environments and no id-token permission.</li><li>No file under src, infra/appservice or infra/api-management-basicv2 changes.</li></ul>'
    }
    @{
        Key                = 'S2'
        Suffix             = 'bundle'
        Type               = 'User Story'
        Title              = 'APIM 007: APIops CLI tooling and native bundle'
        Description        = '<div>Pin @azure-tools/apiops-cli 1.0.4 in tools/apiops-cli with a committed lockfile. Author the environment-neutral artifacts.007 native bundle, the ownership filter and the expected inventory with a defined schema.</div>'
        AcceptanceCriteria = '<ul><li>The lockfile resolves @azure-tools/apiops-cli exactly 1.0.4 with integrity, and the local apiops binary reports version 1.0.4.</li><li>artifacts.007 contains the Weather and Software Version APIs, two backends, the demo-environment named value and the demo product, all with sentinel values only.</li><li>No subscriptions, groups, loggers, diagnostics or instrumentationKey paths exist in the bundle.</li><li>The inventory records the SHA256 of configuration.007.ownership.yaml and the hash matches.</li><li>Test-Apim007Bundle.ps1 in Authoring mode passes.</li></ul>'
    }
    @{
        Key                = 'S3'
        Suffix             = 'scripts'
        Type               = 'User Story'
        Title              = 'APIM 007: release and validation scripts'
        Description        = '<div>Create the PowerShell 7 release scripts in scripts/apim-007 for bundle checks, neutral contracts, target manifests, overrides, candidate freezing and verification, release state, backend and gateway tests and extraction comparison. Cover them with Pester 5 tests and fixtures.</div>'
        AcceptanceCriteria = '<ul><li>Thirteen scripts exist under scripts/apim-007 and use strict mode with stop on error.</li><li>Invoke-Pester on scripts/apim-007/tests in CI mode passes.</li><li>Invoke-ScriptAnalyzer reports no Error findings for scripts/apim-007.</li><li>Release state rules block promotion while prod is dirty, except a retry of the same candidate or a rollback to a history entry.</li><li>No script prints keys, tokens or full response bodies.</li></ul>'
    }
    @{
        Key                = 'S4'
        Suffix             = 'workflows'
        Type               = 'User Story'
        Title              = 'APIM 007: provisioning, release, extraction and teardown workflows plus setup script'
        Description        = '<div>Create the dedicated 007 GitHub workflows for provisioning, release with dev to prod promotion, extraction to a pull request and teardown. Add the Owner-run setup script in scripts/apim-007-setup that prepares identities, federated credentials, role assignments and GitHub environments.</div>'
        AcceptanceCriteria = '<ul><li>infra-apim-007.yml, release-apiops-007.yml, extract-apiops-007.yml and teardown-apim-007.yml exist and pass actionlint.</li><li>Every action reference is pinned to a full 40 character commit SHA.</li><li>deploy-prod cannot start without deploy-dev success, plan-prod success and a prod-007 approval.</li><li>Teardown deletes only tagged manifest resource IDs, keeps resource groups and never touches shared or legacy resources.</li><li>Every 007 job is gated on the APIM007_ENABLED repository variable.</li><li>Initialize-Apim007Environment.ps1 with WhatIf lists every intended action without writing and refuses untagged resource groups.</li></ul>'
    }
    @{
        Key                = 'S5'
        Suffix             = 'runbook'
        Type               = 'User Story'
        Title              = 'APIM 007: runbook and runtime acceptance'
        Description        = '<div>Write the docs/apim-007-apiops-cli.md runbook and add the 007 row to the README instance table. Run the setup, provisioning, contract capture, baseline release, candidate promotion, rollback, extraction and teardown rehearsal, and record non-secret evidence for each gate.</div>'
        AcceptanceCriteria = '<ul><li>The runbook and README pass markdownlint and make no production security claims.</li><li>Captured OpenAPI and WSDL contracts are reviewed and committed.</li><li>Baseline A is live in dev and prod with the expected x-demo-release header.</li><li>Candidate B reaches dev first, then prod only after approval.</li><li>Rollback by candidate tag and roll forward both succeed; an unknown tag fails before any write.</li><li>A simulated dev gate failure leaves dev dirty and skips plan-prod.</li><li>Extraction produces a policy-only pull request; the dev teardown rehearsal deletes only manifest resources.</li></ul>'
    }
)

#endregion

#region Helpers

function Invoke-Az {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$AllowFailure)
    foreach ($argument in $Arguments) {
        # az is a .cmd wrapper on Windows; these characters break its argument handling.
        if ($argument -match '["%]') { throw "Unsupported character in az argument: $argument" }
        if ($argument -match '[<>&|^]' -and $argument -notmatch '\s') { throw "Argument with shell metacharacters must contain a space to be quoted: $argument" }
    }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & az @Arguments --only-show-errors --output json 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join ' '
    if ($exitCode -ne 0) {
        if ($AllowFailure) { return $null }
        if ($stderr.Length -gt 600) { $stderr = $stderr.Substring(0, 600) + '...' }
        throw "az $(($Arguments | Select-Object -First 3) -join ' ') failed (exit $exitCode): $stderr"
    }
    $text = ($stdout | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return ($text | ConvertFrom-Json -Depth 64)
}

function Get-OrgArguments {
    return @('--org', $Organization)
}

function Test-Pending {
    param($Id)
    return ($Id -is [string] -and $Id.StartsWith($PendingPrefix))
}

function Find-WorkItem {
    param([Parameter(Mandatory = $true)][string]$Type, [Parameter(Mandatory = $true)][string]$Title)
    $escapedTitle = $Title.Replace("'", "''")
    $escapedProject = $Project.Replace("'", "''")
    $wiql = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$escapedProject' AND [System.WorkItemType] = '$Type' AND [System.Title] = '$escapedTitle' AND [System.State] <> 'Removed' ORDER BY [System.Id]"
    $result = @(Invoke-Az -Arguments (@('boards', 'query', '--wiql', $wiql, '--project', $Project) + (Get-OrgArguments)))
    $ids = @($result | Where-Object { $_ } | ForEach-Object { [int]$_.id } | Sort-Object)
    if ($ids.Count -gt 1) { Write-Warning "Multiple $Type items titled '$Title' found ($($ids -join ', ')); using $($ids[0])." }
    if ($ids.Count -gt 0) { return $ids[0] }
    return $null
}

function Sync-WorkItem {
    param([Parameter(Mandatory = $true)][hashtable]$Definition, [Parameter(Mandatory = $true)][string]$Iteration)
    $existing = Find-WorkItem -Type $Definition.Type -Title $Definition.Title
    if ($existing) {
        Write-Host "  Reusing $($Definition.Type) $existing '$($Definition.Title)'"
        return [pscustomobject]@{ Id = $existing; Status = 'reused' }
    }
    $label = "$($Definition.Type) '$($Definition.Title)'"
    if (-not $script:Cmdlet.ShouldProcess($label, "Create in $Project (area '$AreaPath', iteration '$Iteration', tag '$Tag')")) {
        return [pscustomobject]@{ Id = "$PendingPrefix$($Definition.Type)>"; Status = 'would create' }
    }
    $fields = @("System.Tags=$Tag")
    if ($Definition.ContainsKey('AcceptanceCriteria')) { $fields += "Microsoft.VSTS.Common.AcceptanceCriteria=$($Definition.AcceptanceCriteria)" }
    $arguments = @('boards', 'work-item', 'create', '--type', $Definition.Type, '--title', $Definition.Title, '--area', $AreaPath, '--iteration', $Iteration, '--description', $Definition.Description, '--project', $Project) + (Get-OrgArguments) + @('--fields') + $fields
    $created = Invoke-Az -Arguments $arguments
    Write-Host "  Created $($Definition.Type) $($created.id) '$($Definition.Title)'"
    return [pscustomobject]@{ Id = [int]$created.id; Status = 'created' }
}

function Sync-ParentLink {
    param([Parameter(Mandatory = $true)]$ChildId, [Parameter(Mandatory = $true)]$ParentId)
    $label = "work item $ChildId -> parent $ParentId"
    if ((Test-Pending $ChildId) -or (Test-Pending $ParentId)) {
        $null = $script:Cmdlet.ShouldProcess($label, 'Add parent link')
        return 'would link'
    }
    $item = Invoke-Az -Arguments (@('boards', 'work-item', 'show', '--id', "$ChildId", '--expand', 'relations') + (Get-OrgArguments))
    $relations = if ($item.PSObject.Properties['relations'] -and $item.relations) { @($item.relations) } else { @() }
    $parents = @($relations | Where-Object { $_.rel -eq 'System.LinkTypes.Hierarchy-Reverse' })
    $current = $parents | Where-Object { $_.url -match "/workItems/$ParentId$" }
    if ($current) {
        Write-Host "  Parent link $label present"
        return 'present'
    }
    if ($parents.Count -gt 0) {
        Write-Warning "Work item $ChildId already has a different parent ($($parents[0].url)); not changed."
        return 'different parent'
    }
    if ($script:Cmdlet.ShouldProcess($label, 'Add parent link')) {
        $null = Invoke-Az -Arguments (@('boards', 'work-item', 'relation', 'add', '--id', "$ChildId", '--relation-type', 'parent', '--target-id', "$ParentId") + (Get-OrgArguments))
        Write-Host "  Parent link $label added"
        return 'added'
    }
    return 'would link'
}

function Resolve-Iteration {
    if ($IterationPath) { return $IterationPath }
    $iterations = @(Invoke-Az -Arguments (@('boards', 'iteration', 'team', 'list', '--team', $Team, '--timeframe', 'current', '--project', $Project) + (Get-OrgArguments)) -AllowFailure)
    $current = $iterations | Where-Object { $_ -and $_.PSObject.Properties['path'] } | Select-Object -First 1
    if ($current) {
        Write-Host "  Using current $Team iteration '$($current.path)'"
        return [string]$current.path
    }
    Write-Warning "No current iteration found for team $Team; using '$Project'."
    return $Project
}

#endregion

Write-Host 'Prerequisites: az extension add --name azure-devops; az login (or az devops login --organization <org>).'
Write-Host "Target: $Organization / $Project, area '$AreaPath', tag '$Tag'"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI (az) not found on PATH.' }
$extension = Invoke-Az -Arguments @('extension', 'show', '--name', 'azure-devops') -AllowFailure
if (-not $extension) { throw 'The azure-devops az extension is missing. Run: az extension add --name azure-devops' }
if ($WhatIfPreference) { Write-Host 'WhatIf: lookups run, creates and links are only listed.' -ForegroundColor Yellow }

$iteration = Resolve-Iteration

Write-Host 'Epic'
if ($ExistingEpicId) {
    $epicItem = Invoke-Az -Arguments (@('boards', 'work-item', 'show', '--id', "$ExistingEpicId") + (Get-OrgArguments))
    if ($epicItem.fields.'System.WorkItemType' -ne 'Epic') { throw "Work item $ExistingEpicId is a $($epicItem.fields.'System.WorkItemType'), not an Epic." }
    Write-Host "  Reusing Epic $ExistingEpicId '$($epicItem.fields.'System.Title')'"
    $epicResult = [pscustomobject]@{ Id = $ExistingEpicId; Status = 'reused (parameter)' }
    $epicTitle = [string]$epicItem.fields.'System.Title'
}
else {
    $epicResult = Sync-WorkItem -Definition $Epic -Iteration $iteration
    $epicTitle = $Epic.Title
}

Write-Host 'Feature'
$featureResult = Sync-WorkItem -Definition $Feature -Iteration $iteration
$featureLink = Sync-ParentLink -ChildId $featureResult.Id -ParentId $epicResult.Id

Write-Host 'User Stories'
$rows = [System.Collections.Generic.List[object]]::new()
$rows.Add([pscustomobject]@{ Key = 'Epic'; Type = 'Epic'; Id = $epicResult.Id; Status = $epicResult.Status; Parent = ''; Link = ''; Title = $epicTitle; Branch = '' })
$rows.Add([pscustomobject]@{ Key = 'Feature'; Type = 'Feature'; Id = $featureResult.Id; Status = $featureResult.Status; Parent = $epicResult.Id; Link = $featureLink; Title = $Feature.Title; Branch = '' })
foreach ($story in $Stories) {
    $storyResult = Sync-WorkItem -Definition $story -Iteration $iteration
    $link = Sync-ParentLink -ChildId $storyResult.Id -ParentId $featureResult.Id
    $branch = if (Test-Pending $storyResult.Id) { "feature/<$($story.Key) id>-apim007-$($story.Suffix)" } else { "feature/$($storyResult.Id)-apim007-$($story.Suffix)" }
    $rows.Add([pscustomobject]@{ Key = $story.Key; Type = $story.Type; Id = $storyResult.Id; Status = $storyResult.Status; Parent = $featureResult.Id; Link = $link; Title = $story.Title; Branch = $branch })
}

$rows | Format-Table Key, Type, Id, Status, Parent, Link, Branch -AutoSize | Out-String | Write-Host
Write-Host 'Suggested branches (merge in order S1 to S5; commits use AB#<id>, PRs use Fixes AB#<id>):'
$rows | Where-Object { $_.Branch } | ForEach-Object { Write-Host "  $($_.Key): $($_.Branch)" }

$map = [ordered]@{
    organization = $Organization
    project      = $Project
    areaPath     = $AreaPath
    iterationPath = $iteration
    tag          = $Tag
    epic         = [ordered]@{ id = $epicResult.Id; title = $epicTitle }
    feature      = [ordered]@{ id = $featureResult.Id; title = $Feature.Title }
    stories      = @($rows | Where-Object { $_.Key -like 'S*' } | ForEach-Object { [ordered]@{ key = $_.Key; id = $_.Id; title = $_.Title; branch = $_.Branch } })
}
if ($PSCmdlet.ShouldProcess($OutputPath, 'Write work item ID map')) {
    $map | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM
    Write-Host "ID map written to $OutputPath"
}
