<#
.SYNOPSIS
    One-time, Owner-run setup for the APIM 007 APIops CLI promotion demo.

.DESCRIPTION
    Prepares Azure and GitHub for the 007 workflows in two stages:

    Initial      Preflight (context, providers, Basic v2 region check, cost estimate), tagged
                 resource groups, a tag-filtered consumption budget, user-assigned managed
                 identities with one federated credential each, role assignments (RBAC
                 Administrator assignments are ABAC-constrained), nine GitHub environments
                 with protection rules, environment secrets and variables, the Actions
                 pull request permission, an immutable releases attempt and finally the
                 repository variable APIM007_ENABLED=true.

    PostRegistry Run after infra-apim-007.yml target=shared. Grants each environment infra
                 identity an AcrPull-only RBAC Administrator assignment on the registry and
                 publishes REGISTRY_NAME, REGISTRY_LOGIN_SERVER and REGISTRY_ID.

    Stage order: Initial -> infra-apim-007.yml target=shared -> PostRegistry ->
    infra-apim-007.yml target=dev and target=prod.

    Every write honors -WhatIf. Reads (az/gh queries, the public retail prices API and
    a Bicep what-if) still run during -WhatIf. Creates billable resources and identities;
    requires subscription Owner and GitHub repository admin. Never prints tokens.

.PARAMETER Stage
    Initial or PostRegistry.

.PARAMETER SubscriptionId
    Target subscription ID. The current az context is switched to it when different.

.PARAMETER TenantId
    Expected tenant ID; the script stops when the az context tenant differs.

.PARAMETER Location
    Azure region for resource groups and identities. Default canadacentral.

.PARAMETER GitHubRepository
    Repository in owner/name form.

.PARAMETER BudgetAmount
    Monthly budget amount (subscription currency) for resources tagged apimDemo=007. Initial only.

.PARAMETER BudgetAlertEmail
    Budget alert recipient. Initial only.

.PARAMETER ExpiresOn
    Demo expiry date written to the expiresOn tag and used as the budget end date. Initial only.

.PARAMETER ProdReviewers
    GitHub user logins or org/team-slug values required to approve prod-007 and prod-007-teardown. Initial only.

.PARAMETER PreventSelfReview
    prevent_self_review on the reviewed environments. Default $true. A solo demo may pass $false
    (recorded in repository variable APIM007_PREVENT_SELF_REVIEW as reduced control).

.PARAMETER RegistryName
    Name of the registry deployed by infra-apim-007.yml target=shared. PostRegistry only.

.PARAMETER Force
    Skips the single interactive confirmation before writes.

.EXAMPLE
    ./Initialize-Apim007Environment.ps1 -Stage Initial -SubscriptionId <sub> -TenantId <tenant> `
        -GitHubRepository devopsabcs-engineering/APIM_apim-landing-zone-accelerator -BudgetAmount 150 `
        -BudgetAlertEmail admin@contoso.com -ExpiresOn 2026-12-31 -ProdReviewers octocat -WhatIf

.EXAMPLE
    ./Initialize-Apim007Environment.ps1 -Stage PostRegistry -SubscriptionId <sub> -TenantId <tenant> `
        -GitHubRepository devopsabcs-engineering/APIM_apim-landing-zone-accelerator -RegistryName crapimdemo007abc -WhatIf
#>
#Requires -Version 7.2
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Initial', 'PostRegistry')]
    [string]$Stage,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$TenantId,

    [ValidatePattern('^[a-z0-9]+$')]
    [string]$Location = 'canadacentral',

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$')]
    [string]$GitHubRepository,

    [decimal]$BudgetAmount,

    [string]$BudgetAlertEmail,

    [datetime]$ExpiresOn,

    [string[]]$ProdReviewers,

    [bool]$PreventSelfReview = $true,

    [ValidatePattern('^[a-zA-Z0-9]{5,50}$')]
    [string]$RegistryName,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Cmdlet = $PSCmdlet
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

#region Constants

$Roles = @{
    Contributor              = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    Reader                   = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    RbacAdministrator        = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
    ApimServiceContributor   = '312a565d-c81f-4fd8-895a-4e21e48d571c'
    WebsiteContributor       = 'de139f84-1756-47ae-9be6-808fbbe84772'
    AcrPush                  = '8311e382-0749-4cb8-b61a-304f252e45ec'
    AcrPull                  = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    CognitiveServicesOpenAiUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    CognitiveServicesUser    = 'a97b65f3-24c7-4388-baec-2e87135dc908'
}

$Rg = [ordered]@{
    Shared       = 'rg-apim-demo-007-shared'
    DevApim      = 'rg-apim-demo-007-dev-apim'
    DevBackends  = 'rg-apim-demo-007-dev-backends'
    ProdApim     = 'rg-apim-demo-007-prod-apim'
    ProdBackends = 'rg-apim-demo-007-prod-backends'
}

$RgEnvironment = @{
    $Rg.Shared       = 'shared'
    $Rg.DevApim      = 'dev'
    $Rg.DevBackends  = 'dev'
    $Rg.ProdApim     = 'prod'
    $Rg.ProdBackends = 'prod'
}

# Identity key -> name, GitHub environment, tag environment.
$Identities = [ordered]@{
    SharedInfra  = @{ Name = 'id-apim007-shared-infra'; GitHubEnvironment = 'apim-007-shared-infra'; Environment = 'shared' }
    Build        = @{ Name = 'id-apim007-build'; GitHubEnvironment = 'apim-007-build'; Environment = 'shared' }
    DevInfra     = @{ Name = 'id-apim007-dev-infra'; GitHubEnvironment = 'dev-007-infra'; Environment = 'dev' }
    DevRelease   = @{ Name = 'id-apim007-dev-release'; GitHubEnvironment = 'dev-007'; Environment = 'dev' }
    DevTeardown  = @{ Name = 'id-apim007-dev-teardown'; GitHubEnvironment = 'dev-007-teardown'; Environment = 'dev' }
    ProdInfra    = @{ Name = 'id-apim007-prod-infra'; GitHubEnvironment = 'prod-007-infra'; Environment = 'prod' }
    ProdPlan     = @{ Name = 'id-apim007-prod-plan'; GitHubEnvironment = 'prod-007-plan'; Environment = 'prod' }
    ProdRelease  = @{ Name = 'id-apim007-prod-release'; GitHubEnvironment = 'prod-007'; Environment = 'prod' }
    ProdTeardown = @{ Name = 'id-apim007-prod-teardown'; GitHubEnvironment = 'prod-007-teardown'; Environment = 'prod' }
}

$ReviewedEnvironments = @('prod-007', 'prod-007-teardown')
$RegistryVariableEnvironments = @('apim-007-build', 'dev-007-infra', 'prod-007-infra', 'dev-007', 'prod-007')

$OidcIssuer = 'https://token.actions.githubusercontent.com'
$OidcAudience = 'api://AzureADTokenExchange'
$BudgetName = 'budget-apim-demo-007'
$PendingPrefix = '<pending:'

#endregion

#region Helpers

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message"
}

function Test-ShouldProcess {
    param([string]$Target, [string]$Action)
    return $script:Cmdlet.ShouldProcess($Target, $Action)
}

function Test-Pending {
    param([string]$Value)
    return ([string]::IsNullOrEmpty($Value) -or $Value.StartsWith($PendingPrefix))
}

function Invoke-Cli {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure,
        [switch]$Raw
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Tool @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join ' '
    if ($exitCode -ne 0) {
        if ($AllowFailure) { return $null }
        $label = ($Arguments | Select-Object -First 3) -join ' '
        if ($stderr.Length -gt 600) { $stderr = $stderr.Substring(0, 600) + '...' }
        throw "$Tool $label failed (exit $exitCode): $stderr"
    }
    $text = ($stdout | Out-String).Trim()
    if ($Raw) { return $text }
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return ($text | ConvertFrom-Json -Depth 64)
}

function Invoke-Az {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$AllowFailure)
    return Invoke-Cli -Tool 'az' -Arguments ($Arguments + @('--only-show-errors', '--output', 'json')) -AllowFailure:$AllowFailure
}

function Invoke-Gh {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$AllowFailure, [switch]$Raw)
    return Invoke-Cli -Tool 'gh' -Arguments $Arguments -AllowFailure:$AllowFailure -Raw:$Raw
}

function Invoke-WithJsonFile {
    param([Parameter(Mandatory = $true)]$Body, [Parameter(Mandatory = $true)][scriptblock]$Action)
    $file = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "apim007-$([guid]::NewGuid().ToString('N')).json")
    try {
        Set-Content -LiteralPath $file -Value ($Body | ConvertTo-Json -Depth 20) -Encoding utf8NoBOM
        return (& $Action $file)
    }
    finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}

function Get-DeterministicGuid {
    param([Parameter(Mandatory = $true)][string]$Seed)
    $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Seed.ToLowerInvariant()))
    return ([guid]::new([byte[]]$bytes[0..15])).ToString()
}

function Get-RgScope {
    param([string]$Name)
    return "/subscriptions/$SubscriptionId/resourceGroups/$Name"
}

function Get-RoleAssignmentClause {
    param([string]$Source, [string[]]$RoleDefinitionIds, [string[]]$PrincipalIds, [string]$PrincipalType)
    $clauses = @("@$Source[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$($RoleDefinitionIds -join ', ')}")
    if ($PrincipalIds) { $clauses += "@$Source[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {$($PrincipalIds -join ', ')}" }
    if ($PrincipalType) { $clauses += "@$Source[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'$PrincipalType'}" }
    return ($clauses -join ' AND ')
}

function New-RoleAssignmentCondition {
    # -OrRules adds alternatives: each hashtable has RoleDefinitionIds and optional PrincipalIds/PrincipalType.
    param(
        [Parameter(Mandatory = $true)][string[]]$RoleDefinitionIds,
        [string[]]$PrincipalIds,
        [string]$PrincipalType,
        [hashtable[]]$OrRules
    )
    $parts = @{}
    foreach ($source in 'Request', 'Resource') {
        $rules = @(Get-RoleAssignmentClause -Source $source -RoleDefinitionIds $RoleDefinitionIds -PrincipalIds $PrincipalIds -PrincipalType $PrincipalType)
        foreach ($rule in @($OrRules | Where-Object { $_ })) {
            $rules += Get-RoleAssignmentClause -Source $source -RoleDefinitionIds $rule['RoleDefinitionIds'] -PrincipalIds $rule['PrincipalIds'] -PrincipalType $rule['PrincipalType']
        }
        $parts[$source] = if ($rules.Count -eq 1) { $rules[0] } else { ($rules | ForEach-Object { "($_)" }) -join ' OR ' }
    }
    return "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR ($($parts.Request))) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR ($($parts.Resource)))"
}

#endregion

#region Preflight

function Assert-StageParameters {
    if ($Stage -eq 'Initial') {
        $missing = @()
        if ($BudgetAmount -le 0) { $missing += '-BudgetAmount (> 0)' }
        if ($BudgetAlertEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { $missing += '-BudgetAlertEmail' }
        if ($null -eq $ExpiresOn -or $ExpiresOn -eq [datetime]::MinValue) { $missing += '-ExpiresOn' }
        elseif ($ExpiresOn.Date -le (Get-Date).Date) { $missing += '-ExpiresOn (future date)' }
        if (-not $ProdReviewers -or $ProdReviewers.Count -eq 0) { $missing += '-ProdReviewers' }
        if ($missing) { throw "Stage Initial requires: $($missing -join ', ')" }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($RegistryName)) { throw 'Stage PostRegistry requires -RegistryName.' }
    }
}

function Assert-Tooling {
    foreach ($tool in 'az', 'gh') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool CLI not found on PATH." }
    }
    $null = Invoke-Gh -Arguments @('api', 'user')
}

function Confirm-AzureContext {
    Write-Section 'Azure context'
    $account = Invoke-Az -Arguments @('account', 'show')
    if (-not $account) { throw 'Not signed in to Azure. Run az login --tenant <tenant> first.' }
    if ($account.id -ne $SubscriptionId) {
        Write-Info "Switching az context to subscription $SubscriptionId (local CLI setting)."
        $null = Invoke-Az -Arguments @('account', 'set', '--subscription', $SubscriptionId)
        $account = Invoke-Az -Arguments @('account', 'show')
    }
    if ($account.id -ne $SubscriptionId) { throw "Subscription mismatch: context $($account.id), expected $SubscriptionId." }
    if ($account.tenantId -ne $TenantId) { throw "Tenant mismatch: context $($account.tenantId), expected $TenantId." }
    Write-Info "Tenant       $($account.tenantId)"
    Write-Info "Subscription $($account.name) ($($account.id))"
    Write-Info "Signed in as $($account.user.name) ($($account.user.type))"

    if ($account.user.type -eq 'user') {
        $me = Invoke-Az -Arguments @('ad', 'signed-in-user', 'show') -AllowFailure
        if ($me) {
            $assignments = @(Invoke-Az -Arguments @('role', 'assignment', 'list', '--assignee', $me.id, '--scope', "/subscriptions/$SubscriptionId", '--include-inherited', '--include-groups') -AllowFailure)
            $isOwner = $assignments | Where-Object { $_ -and $_.roleDefinitionName -eq 'Owner' }
            if (-not $isOwner) { Write-Warning 'No direct or group Owner assignment found at subscription scope; writes may fail.' }
        }
    }
}

function Get-RepositoryInfo {
    Write-Section 'GitHub repository'
    $repo = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository")
    if (-not $repo.permissions.admin) { throw "Repository admin permission required on $GitHubRepository." }
    Write-Info "Repository $($repo.full_name) (id $($repo.id), owner type $($repo.owner.type), visibility $($repo.visibility))"
    return $repo
}

function Get-OidcSubjectTemplate {
    param($Repo)
    $custom = Invoke-Gh -Arguments @('api', "repos/$($Repo.full_name)/actions/oidc/customization/sub") -AllowFailure
    if ($custom -and -not $custom.use_default -and $custom.include_claim_keys) {
        Write-Info "Repository OIDC subject customization: $($custom.include_claim_keys -join ', ')"
        return @($custom.include_claim_keys)
    }
    if ($Repo.owner.type -eq 'Organization') {
        $org = Invoke-Gh -Arguments @('api', "orgs/$($Repo.owner.login)/actions/oidc/customization/sub") -AllowFailure
        if ($org -and $org.include_claim_keys) {
            Write-Info "Organization OIDC subject customization: $($org.include_claim_keys -join ', ')"
            return @($org.include_claim_keys)
        }
        if (-not $org) { Write-Warning 'Could not read organization OIDC customization; assuming the default subject format.' }
    }
    Write-Info 'OIDC subject format: default (repo:<owner>/<repo>:environment:<name>)'
    return $null
}

function Get-OidcSubject {
    param($Repo, [string[]]$ClaimKeys, [string]$EnvironmentName)
    if (-not $ClaimKeys) { return "repo:$($Repo.full_name):environment:$EnvironmentName" }
    $parts = foreach ($key in $ClaimKeys) {
        switch ($key) {
            'repo' { "repo:$($Repo.full_name)" }
            'context' { "environment:$EnvironmentName" }
            'environment' { "environment:$EnvironmentName" }
            'repository' { "repository:$($Repo.full_name)" }
            'repository_owner' { "repository_owner:$($Repo.owner.login)" }
            'repository_id' { "repository_id:$($Repo.id)" }
            'repository_owner_id' { "repository_owner_id:$($Repo.owner.id)" }
            'repository_visibility' { "repository_visibility:$($Repo.visibility)" }
            default { throw "OIDC claim key '$key' varies per run and cannot be used in a fixed federated credential subject." }
        }
    }
    return ($parts -join ':')
}

function Register-ResourceProviders {
    Write-Section 'Resource providers'
    foreach ($ns in 'Microsoft.ApiManagement', 'Microsoft.Web', 'Microsoft.ContainerRegistry', 'Microsoft.Insights', 'Microsoft.OperationalInsights', 'Microsoft.ManagedIdentity', 'Microsoft.Consumption', 'Microsoft.CognitiveServices') {
        $provider = Invoke-Az -Arguments @('provider', 'show', '--namespace', $ns)
        if ($provider.registrationState -eq 'Registered') {
            Write-Info "$ns registered"
            continue
        }
        if (Test-ShouldProcess -Target $ns -Action 'Register resource provider') {
            $null = Invoke-Az -Arguments @('provider', 'register', '--namespace', $ns, '--wait')
            Write-Info "$ns registered"
        }
    }
}

function Assert-BasicV2Region {
    Write-Section 'API Management region check'
    $provider = Invoke-Az -Arguments @('provider', 'show', '--namespace', 'Microsoft.ApiManagement')
    $serviceType = $provider.resourceTypes | Where-Object { $_.resourceType -eq 'service' } | Select-Object -First 1
    $regions = @($serviceType.locations | ForEach-Object { ($_ -replace '\s', '').ToLowerInvariant() })
    if ($regions -notcontains $Location) { throw "Microsoft.ApiManagement/service is not offered in $Location." }
    Write-Info "Microsoft.ApiManagement/service is offered in $Location. Basic v2 SKU is confirmed by the Bicep what-if after resource group creation."
}

function Get-RetailPrice {
    param([string]$Filter, [scriptblock]$Where)
    $uri = 'https://prices.azure.com/api/retail/prices?currencyCode=USD&$filter=' + [uri]::EscapeDataString($Filter)
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
        return ($response.Items | Where-Object $Where | Sort-Object unitPrice | Select-Object -First 1)
    }
    catch {
        return $null
    }
}

function Show-CostEstimate {
    Write-Section "Cost estimate (retail USD list prices, $Location, looked up now)"
    $base = "armRegionName eq '$Location' and priceType eq 'Consumption'"
    $items = @(
        @{ Item = 'API Management Basic v2'; Quantity = 2; Filter = "serviceName eq 'API Management' and $base"; Where = { $_.skuName -match 'Basic v2' -and $_.meterName -notmatch 'Call|Request' } }
        @{ Item = 'App Service plan B1 Linux'; Quantity = 2; Filter = "serviceName eq 'Azure App Service' and skuName eq 'B1' and $base"; Where = { $_.productName -match 'Linux' } }
        @{ Item = 'Container Registry Basic'; Quantity = 1; Filter = "serviceName eq 'Container Registry' and skuName eq 'Basic' and $base"; Where = { $_.meterName -match 'Registry Unit' } }
        @{ Item = 'Log Analytics ingestion (per GB)'; Quantity = 2; Filter = "serviceName eq 'Log Analytics' and $base"; Where = { $_.meterName -match 'Data Ingestion' -and $_.unitPrice -gt 0 } }
    )
    $rows = foreach ($entry in $items) {
        $price = Get-RetailPrice -Filter $entry.Filter -Where $entry.Where
        $monthly = $null
        if ($price) {
            switch -Regex ($price.unitOfMeasure) {
                'Hour' { $monthly = [math]::Round($price.unitPrice * 730 * $entry.Quantity, 2) }
                'Day' { $monthly = [math]::Round($price.unitPrice * 30.4 * $entry.Quantity, 2) }
                'Month' { $monthly = [math]::Round($price.unitPrice * $entry.Quantity, 2) }
            }
        }
        [pscustomobject]@{
            Item          = $entry.Item
            Quantity      = $entry.Quantity
            UnitPrice     = if ($price) { $price.unitPrice } else { 'lookup unavailable' }
            Unit          = if ($price) { $price.unitOfMeasure } else { '' }
            ApproxMonthly = if ($null -ne $monthly) { $monthly } else { 'usage based' }
        }
    }
    $rows | Format-Table -AutoSize | Out-String | Write-Host
    Write-Info 'AI gateway (per environment, canadaeast): Azure OpenAI gpt-4o Standard and Content Safety S0 are pay per use with no fixed monthly fee; demo traffic is a few thousand tokens per release.'
    Write-Info "Budget: $BudgetAmount per month for resources tagged apimDemo=007, alerts to $BudgetAlertEmail, expires $($ExpiresOn.ToString('yyyy-MM-dd'))."
}

#endregion

#region Azure resources

function Assert-ResourceGroupTags {
    Write-Section 'Resource group ownership check'
    foreach ($name in $Rg.Values) {
        $exists = Invoke-Az -Arguments @('group', 'exists', '--name', $name)
        if (-not $exists) {
            Write-Info "$name does not exist"
            continue
        }
        $group = Invoke-Az -Arguments @('group', 'show', '--name', $name)
        $tags = $group.tags
        $demo = if ($tags -and $tags.PSObject.Properties['apimDemo']) { $tags.apimDemo } else { $null }
        $envTag = if ($tags -and $tags.PSObject.Properties['environment']) { $tags.environment } else { $null }
        if ($demo -ne '007') { throw "Resource group $name exists without tag apimDemo=007. Refusing to continue." }
        if ($envTag -ne $RgEnvironment[$name]) { throw "Resource group $name has environment tag '$envTag', expected '$($RgEnvironment[$name])'." }
        Write-Info "$name exists and is tagged apimDemo=007"
    }
}

function Sync-ResourceGroups {
    Write-Section 'Resource groups'
    $expires = $ExpiresOn.ToString('yyyy-MM-dd')
    foreach ($name in $Rg.Values) {
        $exists = Invoke-Az -Arguments @('group', 'exists', '--name', $name)
        if ($exists) {
            Write-Info "$name exists (kept)"
            continue
        }
        if (Test-ShouldProcess -Target $name -Action "Create resource group in $Location") {
            $null = Invoke-Az -Arguments @('group', 'create', '--name', $name, '--location', $Location, '--tags', 'apimDemo=007', "environment=$($RgEnvironment[$name])", "expiresOn=$expires", 'owner=apim-demo-007')
            Write-Info "$name created"
        }
    }
}

function Sync-Budget {
    Write-Section 'Consumption budget'
    $url = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/budgets/$($BudgetName)?api-version=2023-05-01"
    $existing = Invoke-Az -Arguments @('rest', '--method', 'get', '--url', $url) -AllowFailure
    if ($existing) {
        Write-Info "$BudgetName exists (amount $($existing.properties.amount)); left unchanged"
        if ([decimal]$existing.properties.amount -ne $BudgetAmount) { Write-Warning "Existing budget amount differs from -BudgetAmount $BudgetAmount; update it in the portal if intended." }
        return
    }
    $now = (Get-Date).ToUniversalTime()
    $start = [datetime]::new($now.Year, $now.Month, 1, 0, 0, 0, [DateTimeKind]::Utc)
    $end = $ExpiresOn.Date
    if ($end -lt $start.AddMonths(1)) { $end = $start.AddMonths(1) }
    $notification = {
        param([int]$Threshold, [string]$Type)
        @{ enabled = $true; operator = 'GreaterThan'; threshold = $Threshold; thresholdType = $Type; contactEmails = @($BudgetAlertEmail) }
    }
    $body = @{
        properties = @{
            category      = 'Cost'
            amount        = $BudgetAmount
            timeGrain     = 'Monthly'
            timePeriod    = @{
                startDate = $start.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
                endDate   = $end.ToString('yyyy-MM-ddT00:00:00Z', [cultureinfo]::InvariantCulture)
            }
            filter        = @{ tags = @{ name = 'apimDemo'; operator = 'In'; values = @('007') } }
            notifications = @{
                Actual_GreaterThan_50_Percent     = (& $notification 50 'Actual')
                Actual_GreaterThan_80_Percent     = (& $notification 80 'Actual')
                Actual_GreaterThan_100_Percent    = (& $notification 100 'Actual')
                Forecasted_GreaterThan_100_Percent = (& $notification 100 'Forecasted')
            }
        }
    }
    if (Test-ShouldProcess -Target $BudgetName -Action "Create subscription budget $BudgetAmount/month filtered on tag apimDemo=007") {
        $null = Invoke-WithJsonFile -Body $body -Action { param($file) Invoke-Az -Arguments @('rest', '--method', 'put', '--url', $url, '--body', "@$file") }
        Write-Info "$BudgetName created"
    }
}

function Sync-Identity {
    param([Parameter(Mandatory = $true)][hashtable]$Definition)
    $all = @(Invoke-Az -Arguments @('identity', 'list', '--resource-group', $Rg.Shared) -AllowFailure)
    $found = $all | Where-Object { $_ -and $_.name -eq $Definition.Name } | Select-Object -First 1
    if (-not $found -and (Test-ShouldProcess -Target $Definition.Name -Action "Create user-assigned managed identity in $($Rg.Shared)")) {
        $found = Invoke-Az -Arguments @('identity', 'create', '--name', $Definition.Name, '--resource-group', $Rg.Shared, '--location', $Location, '--tags', 'apimDemo=007', "environment=$($Definition.Environment)", 'owner=apim-demo-007')
        Write-Info "$($Definition.Name) created"
    }
    elseif ($found) {
        Write-Info "$($Definition.Name) exists"
    }
    if (-not $found) {
        return [pscustomobject]@{ Name = $Definition.Name; ClientId = "$PendingPrefix$($Definition.Name) clientId>"; PrincipalId = "$PendingPrefix$($Definition.Name) principalId>"; GitHubEnvironment = $Definition.GitHubEnvironment }
    }
    return [pscustomobject]@{ Name = $found.name; ClientId = $found.clientId; PrincipalId = $found.principalId; GitHubEnvironment = $Definition.GitHubEnvironment }
}

function Get-ExistingIdentity {
    param([Parameter(Mandatory = $true)][hashtable]$Definition)
    $all = @(Invoke-Az -Arguments @('identity', 'list', '--resource-group', $Rg.Shared))
    $found = $all | Where-Object { $_ -and $_.name -eq $Definition.Name } | Select-Object -First 1
    if (-not $found) { throw "Identity $($Definition.Name) not found in $($Rg.Shared); run -Stage Initial first." }
    return [pscustomobject]@{ Name = $found.name; ClientId = $found.clientId; PrincipalId = $found.principalId; GitHubEnvironment = $Definition.GitHubEnvironment }
}

function Sync-FederatedCredential {
    param([Parameter(Mandatory = $true)]$Identity, [Parameter(Mandatory = $true)][string]$Subject)
    $credentialName = "gh-$($Identity.GitHubEnvironment)"
    $existing = @()
    if (-not (Test-Pending $Identity.PrincipalId)) {
        $existing = @(Invoke-Az -Arguments @('identity', 'federated-credential', 'list', '--identity-name', $Identity.Name, '--resource-group', $Rg.Shared))
    }
    $match = $existing | Where-Object { $_ -and $_.name -eq $credentialName } | Select-Object -First 1
    if ($match) {
        if ($match.subject -ne $Subject -or $match.issuer -ne $OidcIssuer) {
            throw "Federated credential $credentialName on $($Identity.Name) has subject '$($match.subject)', expected '$Subject'. Fix it manually."
        }
        Write-Info "$($Identity.Name): federated credential $credentialName present"
        return
    }
    if (Test-ShouldProcess -Target "$($Identity.Name)/$credentialName" -Action "Create federated credential subject '$Subject'") {
        $null = Invoke-Az -Arguments @('identity', 'federated-credential', 'create', '--name', $credentialName, '--identity-name', $Identity.Name, '--resource-group', $Rg.Shared, '--issuer', $OidcIssuer, '--subject', $Subject, '--audiences', $OidcAudience)
        Write-Info "$($Identity.Name): federated credential $credentialName created"
    }
}

function Sync-RoleAssignment {
    param(
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][string]$RoleName,
        [Parameter(Mandatory = $true)][string]$Scope,
        [string]$Condition
    )
    $roleId = $Roles[$RoleName]
    $label = "$($Identity.Name) -> $RoleName @ $Scope"
    if (Test-Pending $Identity.PrincipalId) {
        $null = Test-ShouldProcess -Target $label -Action $(if ($Condition) { "Assign role with condition: $Condition" } else { 'Assign role' })
        return
    }
    $existing = @(Invoke-Az -Arguments @('role', 'assignment', 'list', '--scope', $Scope, '--role', $roleId) -AllowFailure)
    $match = $existing | Where-Object { $_ -and $_.principalId -eq $Identity.PrincipalId -and $_.scope -ieq $Scope } | Select-Object -First 1
    $name = Get-DeterministicGuid -Seed "$Scope|$($Identity.PrincipalId)|$roleId"
    if ($match) {
        $actual = if ($match.PSObject.Properties['condition']) { [string]$match.condition } else { '' }
        if (($actual -replace '\s', '') -eq ([string]$Condition -replace '\s', '')) {
            Write-Info "$label present"
            return
        }
        if (-not $Condition -or -not $actual) {
            Write-Warning "$label exists with a different condition; review it manually."
            return
        }
        # Same role, principal and scope: update the condition of the existing assignment in place.
        if (-not (Test-ShouldProcess -Target $label -Action "Update role assignment condition to: $Condition")) { return }
        $name = [string]$match.name
    }
    elseif (-not (Test-ShouldProcess -Target $label -Action $(if ($Condition) { "Assign role with condition: $Condition" } else { 'Assign role' }))) { return }

    $properties = @{
        roleDefinitionId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleDefinitions/$roleId"
        principalId      = $Identity.PrincipalId
        principalType    = 'ServicePrincipal'
        description      = "apim-demo-007 setup: $($Identity.GitHubEnvironment)"
    }
    if ($Condition) {
        $properties.condition = $Condition
        $properties.conditionVersion = '2.0'
    }
    $url = "https://management.azure.com$Scope/providers/Microsoft.Authorization/roleAssignments/$($name)?api-version=2022-04-01"
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $null = Invoke-WithJsonFile -Body @{ properties = $properties } -Action { param($file) Invoke-Az -Arguments @('rest', '--method', 'put', '--url', $url, '--body', "@$file") }
            Write-Info "$label assigned"
            return
        }
        catch {
            if ($_.Exception.Message -match 'PrincipalNotFound' -and $attempt -lt 6) {
                Write-Info "Principal not replicated yet; retrying in 20 seconds ($attempt/6)"
                Start-Sleep -Seconds 20
                continue
            }
            throw
        }
    }
}

function Invoke-ApimWhatIf {
    param([Parameter(Mandatory = $true)]$ReleaseIdentity)
    Write-Section 'Bicep what-if (SKU and region check, read-only)'
    $exists = Invoke-Az -Arguments @('group', 'exists', '--name', $Rg.DevApim)
    if (-not $exists -or (Test-Pending $ReleaseIdentity.PrincipalId)) {
        Write-Info "Skipped: $($Rg.DevApim) or the dev release identity does not exist yet."
        return
    }
    $template = Join-Path $script:RepoRoot 'infra/apim-demo-007/apim.bicep'
    $parameters = Join-Path $script:RepoRoot 'infra/apim-demo-007/apim.parameters.dev.json'
    $result = Invoke-Az -Arguments @('deployment', 'group', 'what-if', '--resource-group', $Rg.DevApim, '--template-file', $template, '--parameters', "@$parameters", '--parameters', "releasePrincipalId=$($ReleaseIdentity.PrincipalId)", "location=$Location", '--no-pretty-print')
    $changes = @($result.changes)
    Write-Info "what-if succeeded: $($changes.Count) resource change(s) predicted for $($Rg.DevApim); nothing was deployed."
}

#endregion

#region GitHub

function Resolve-Reviewers {
    $resolved = foreach ($login in $ProdReviewers) {
        if ($login -match '^([^/]+)/([^/]+)$') {
            $team = Invoke-Gh -Arguments @('api', "orgs/$($Matches[1])/teams/$($Matches[2])")
            @{ type = 'Team'; id = [long]$team.id }
        }
        else {
            $user = Invoke-Gh -Arguments @('api', "users/$login")
            @{ type = 'User'; id = [long]$user.id }
        }
    }
    Write-Info "Resolved $(@($resolved).Count) prod reviewer(s)"
    return @($resolved)
}

function Sync-GitHubEnvironment {
    param([Parameter(Mandatory = $true)][string]$Name, [array]$Reviewers)
    $repo = $GitHubRepository
    $existing = Invoke-Gh -Arguments @('api', "repos/$repo/environments/$Name") -AllowFailure
    $body = @{
        wait_timer               = 0
        can_admins_bypass        = $false
        deployment_branch_policy = @{ protected_branches = $false; custom_branch_policies = $true }
        reviewers                = @()
    }
    $describe = 'branch policy main, admin bypass off'
    if ($ReviewedEnvironments -contains $Name) {
        $body.reviewers = @($Reviewers)
        $body.prevent_self_review = $PreventSelfReview
        $describe += ", $(@($Reviewers).Count) required reviewer(s), prevent_self_review=$PreventSelfReview"
    }
    $action = if ($existing) { "Update environment protection ($describe)" } else { "Create environment ($describe)" }
    if (Test-ShouldProcess -Target "GitHub environment $Name" -Action $action) {
        $null = Invoke-WithJsonFile -Body $body -Action { param($file) Invoke-Gh -Arguments @('api', '-X', 'PUT', "repos/$repo/environments/$Name", '--input', $file) }
        Write-Info "$Name configured"
    }

    $policies = Invoke-Gh -Arguments @('api', "repos/$repo/environments/$Name/deployment-branch-policies") -AllowFailure
    $list = if ($policies -and $policies.PSObject.Properties['branch_policies']) { @($policies.branch_policies) } else { @() }
    $main = $list | Where-Object { $_.name -eq 'main' -and (-not $_.PSObject.Properties['type'] -or $_.type -eq 'branch') }
    $others = $list | Where-Object { $_.name -ne 'main' }
    if ($others) { Write-Warning "$Name has additional deployment branch policies: $(($others | ForEach-Object name) -join ', '). Review them." }
    if ($main) {
        Write-Info "$Name branch policy main present"
    }
    elseif (Test-ShouldProcess -Target "GitHub environment $Name" -Action 'Add deployment branch policy main') {
        $null = Invoke-Gh -Arguments @('api', '-X', 'POST', "repos/$repo/environments/$Name/deployment-branch-policies", '-f', 'name=main', '-f', 'type=branch')
        Write-Info "$Name branch policy main added"
    }
}

function Assert-ReviewedEnvironment {
    param([string]$Name)
    if ($WhatIfPreference) { return }
    $environment = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository/environments/$Name")
    if ($environment.can_admins_bypass) { throw "$Name still allows admin bypass." }
    $rule = @($environment.protection_rules) | Where-Object { $_.type -eq 'required_reviewers' } | Select-Object -First 1
    if (-not $rule -or @($rule.reviewers).Count -eq 0) { throw "$Name has no required reviewers." }
    if ([bool]$rule.prevent_self_review -ne $PreventSelfReview) { throw "$Name prevent_self_review is $($rule.prevent_self_review), expected $PreventSelfReview." }
    Write-Info "$Name protection verified"
}

function Set-EnvironmentSecret {
    param([string]$Environment, [string]$Name, [string]$Value)
    if (Test-ShouldProcess -Target "$Environment secret $Name" -Action 'Set environment secret') {
        if (Test-Pending $Value) { throw "Cannot set $Name on ${Environment}: value is not available yet." }
        $null = Invoke-Gh -Arguments @('secret', 'set', $Name, '--env', $Environment, '--repo', $GitHubRepository, '--body', $Value) -Raw
        Write-Info "$Environment secret $Name set"
    }
}

function Set-EnvironmentVariable {
    param([string]$Environment, [string]$Name, [string]$Value)
    $current = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository/environments/$Environment/variables/$Name") -AllowFailure
    if ($current -and $current.value -eq $Value) {
        Write-Info "$Environment variable $Name unchanged"
        return
    }
    if (Test-ShouldProcess -Target "$Environment variable $Name" -Action "Set to '$Value'") {
        if (Test-Pending $Value) { throw "Cannot set $Name on ${Environment}: value is not available yet." }
        $null = Invoke-Gh -Arguments @('variable', 'set', $Name, '--env', $Environment, '--repo', $GitHubRepository, '--body', $Value) -Raw
        Write-Info "$Environment variable $Name set"
    }
}

function Set-RepositoryVariable {
    param([string]$Name, [string]$Value)
    $current = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository/actions/variables/$Name") -AllowFailure
    if ($current -and $current.value -eq $Value) {
        Write-Info "Repository variable $Name unchanged"
        return
    }
    if (Test-ShouldProcess -Target "Repository variable $Name" -Action "Set to '$Value'") {
        $null = Invoke-Gh -Arguments @('variable', 'set', $Name, '--repo', $GitHubRepository, '--body', $Value) -Raw
        Write-Info "Repository variable $Name set"
    }
}

function Enable-ActionsPullRequestPermission {
    $current = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository/actions/permissions/workflow")
    if ($current.can_approve_pull_request_reviews) {
        Write-Info 'Actions may already create and approve pull requests'
        return
    }
    if (Test-ShouldProcess -Target $GitHubRepository -Action 'Allow GitHub Actions to create and approve pull requests') {
        $result = Invoke-Gh -Arguments @('api', '-X', 'PUT', "repos/$GitHubRepository/actions/permissions/workflow", '-f', "default_workflow_permissions=$($current.default_workflow_permissions)", '-F', 'can_approve_pull_request_reviews=true') -AllowFailure -Raw
        if ($null -eq $result) {
            Write-Warning 'Actions cannot be allowed to create pull requests (blocked by organization or enterprise policy). extract-apiops-007.yml uploads the extraction as an artifact; open the pull request manually.'
            return
        }
        Write-Info 'Actions pull request permission enabled'
    }
}

function Enable-ImmutableRelease {
    $current = Invoke-Gh -Arguments @('api', "repos/$GitHubRepository/immutable-releases") -AllowFailure
    if ($current -and $current.PSObject.Properties['enabled'] -and $current.enabled) {
        Write-Info 'Immutable releases already enabled'
        return 'enabled'
    }
    if (Test-ShouldProcess -Target $GitHubRepository -Action 'Enable immutable releases') {
        $result = Invoke-Gh -Arguments @('api', '-X', 'PUT', "repos/$GitHubRepository/immutable-releases") -AllowFailure -Raw
        if ($null -eq $result) {
            Write-Warning 'Immutable releases could not be enabled (API unavailable for this repository or plan). Trusted hashes still come from job outputs and release-state history.'
            return 'unavailable'
        }
        Write-Info 'Immutable releases enabled'
        return 'enabled'
    }
    return 'not attempted (WhatIf)'
}

#endregion

#region Stages

function Invoke-InitialStage {
    Write-Section "Stage Initial for $GitHubRepository"
    Assert-BasicV2Region
    Show-CostEstimate
    Assert-ResourceGroupTags

    if (-not $WhatIfPreference -and -not $Force -and -not $script:Cmdlet.ShouldContinue(
            'This creates billable Azure resources, managed identities with role assignments and GitHub environment settings. Continue?',
            'APIM 007 setup')) {
        throw 'Cancelled by user.'
    }

    Register-ResourceProviders
    Sync-ResourceGroups
    Sync-Budget

    Write-Section 'Managed identities and federated credentials'
    $repo = $script:RepoInfo
    $claimKeys = Get-OidcSubjectTemplate -Repo $repo
    $ids = [ordered]@{}
    foreach ($key in $Identities.Keys) {
        $ids[$key] = Sync-Identity -Definition $Identities[$key]
        $subject = Get-OidcSubject -Repo $repo -ClaimKeys $claimKeys -EnvironmentName $Identities[$key].GitHubEnvironment
        Sync-FederatedCredential -Identity $ids[$key] -Subject $subject
    }

    Write-Section 'Role assignments'
    $sharedScope = Get-RgScope $Rg.Shared
    Sync-RoleAssignment -Identity $ids.SharedInfra -RoleName 'Contributor' -Scope $sharedScope
    Sync-RoleAssignment -Identity $ids.SharedInfra -RoleName 'RbacAdministrator' -Scope $sharedScope `
        -Condition (New-RoleAssignmentCondition -RoleDefinitionIds @($Roles.AcrPush, $Roles.AcrPull) -PrincipalType 'ServicePrincipal')

    foreach ($envName in 'dev', 'prod') {
        $prefix = (Get-Culture).TextInfo.ToTitleCase($envName)
        $infra = $ids["$($prefix)Infra"]
        $release = $ids["$($prefix)Release"]
        $teardown = $ids["$($prefix)Teardown"]
        $envScopes = @((Get-RgScope $Rg["$($prefix)Apim"]), (Get-RgScope $Rg["$($prefix)Backends"]))
        $releaseRoles = @($Roles.ApimServiceContributor, $Roles.Reader, $Roles.WebsiteContributor)
        $releaseCondition = New-RoleAssignmentCondition -RoleDefinitionIds $releaseRoles -PrincipalIds @($release.PrincipalId)
        # ai.bicep (APIM resource group) grants the APIM managed identity and the infra identity
        # Cognitive Services data roles; the APIM identity changes when APIM is recreated.
        $apimCondition = New-RoleAssignmentCondition -RoleDefinitionIds $releaseRoles -PrincipalIds @($release.PrincipalId) `
            -OrRules @(@{ RoleDefinitionIds = @($Roles.CognitiveServicesOpenAiUser, $Roles.CognitiveServicesUser); PrincipalType = 'ServicePrincipal' })
        foreach ($scope in $envScopes) {
            $condition = if ($scope -eq (Get-RgScope $Rg["$($prefix)Apim"])) { $apimCondition } else { $releaseCondition }
            Sync-RoleAssignment -Identity $infra -RoleName 'Contributor' -Scope $scope
            Sync-RoleAssignment -Identity $infra -RoleName 'RbacAdministrator' -Scope $scope -Condition $condition
            Sync-RoleAssignment -Identity $teardown -RoleName 'Contributor' -Scope $scope
        }
    }

    Sync-RoleAssignment -Identity $ids.DevRelease -RoleName 'Reader' -Scope (Get-RgScope $Rg.ProdApim)
    Sync-RoleAssignment -Identity $ids.ProdRelease -RoleName 'Reader' -Scope (Get-RgScope $Rg.DevApim)
    foreach ($name in $Rg.ProdApim, $Rg.ProdBackends, $Rg.DevApim) {
        Sync-RoleAssignment -Identity $ids.ProdPlan -RoleName 'Reader' -Scope (Get-RgScope $name)
    }

    Invoke-ApimWhatIf -ReleaseIdentity $ids.DevRelease

    Write-Section 'GitHub environments'
    $reviewers = Resolve-Reviewers
    foreach ($key in $Identities.Keys) {
        Sync-GitHubEnvironment -Name $Identities[$key].GitHubEnvironment -Reviewers $reviewers
    }
    foreach ($name in $ReviewedEnvironments) { Assert-ReviewedEnvironment -Name $name }

    Write-Section 'Environment secrets and variables'
    foreach ($key in $Identities.Keys) {
        $environment = $Identities[$key].GitHubEnvironment
        Set-EnvironmentSecret -Environment $environment -Name 'AZURE_CLIENT_ID' -Value $ids[$key].ClientId
        Set-EnvironmentSecret -Environment $environment -Name 'AZURE_TENANT_ID' -Value $TenantId
        Set-EnvironmentSecret -Environment $environment -Name 'AZURE_SUBSCRIPTION_ID' -Value $SubscriptionId
        Set-EnvironmentVariable -Environment $environment -Name 'EXPECTED_TENANT_ID' -Value $TenantId
        Set-EnvironmentVariable -Environment $environment -Name 'EXPECTED_SUBSCRIPTION_ID' -Value $SubscriptionId
    }
    Set-EnvironmentVariable -Environment 'dev-007-infra' -Name 'RELEASE_PRINCIPAL_ID' -Value $ids.DevRelease.PrincipalId
    Set-EnvironmentVariable -Environment 'prod-007-infra' -Name 'RELEASE_PRINCIPAL_ID' -Value $ids.ProdRelease.PrincipalId
    Set-EnvironmentVariable -Environment 'apim-007-shared-infra' -Name 'PUSH_PRINCIPAL_ID' -Value $ids.Build.PrincipalId

    Write-Section 'Repository settings'
    Enable-ActionsPullRequestPermission
    $immutable = Enable-ImmutableRelease
    Set-RepositoryVariable -Name 'APIM007_PREVENT_SELF_REVIEW' -Value $PreventSelfReview.ToString().ToLowerInvariant()
    if (-not $PreventSelfReview) { Write-Warning 'prevent_self_review is off: a single person can approve their own prod release (reduced control, record it in the runbook).' }
    Set-RepositoryVariable -Name 'APIM007_ENABLED' -Value 'true'

    Write-Section 'Summary (non-secret)'
    $ids.Values | Select-Object Name, GitHubEnvironment, ClientId, PrincipalId | Format-Table -AutoSize | Out-String | Write-Host
    Write-Info "Resource groups: $($Rg.Values -join ', ')"
    Write-Info "Immutable releases: $immutable"
    Write-Info 'Next: run infra-apim-007.yml with target=shared, then this script with -Stage PostRegistry -RegistryName <registryName output>.'
}

function Invoke-PostRegistryStage {
    Write-Section "Stage PostRegistry for $GitHubRepository"
    $registry = Invoke-Az -Arguments @('acr', 'show', '--name', $RegistryName, '--resource-group', $Rg.Shared)
    $tags = $registry.tags
    if (-not $tags -or -not $tags.PSObject.Properties['apimDemo'] -or $tags.apimDemo -ne '007' -or $tags.environment -ne 'shared') {
        throw "Registry $RegistryName is not tagged apimDemo=007 and environment=shared."
    }
    Write-Info "Registry $($registry.name) ($($registry.loginServer)) verified"

    $build = Get-ExistingIdentity -Definition $Identities.Build
    $push = @(Invoke-Az -Arguments @('role', 'assignment', 'list', '--scope', $registry.id, '--role', $Roles.AcrPush) -AllowFailure) |
        Where-Object { $_ -and $_.principalId -eq $build.PrincipalId }
    if (-not $push) { Write-Warning "AcrPush for $($build.Name) not found on the registry; check the shared deployment." }

    if (-not $WhatIfPreference -and -not $Force -and -not $script:Cmdlet.ShouldContinue(
            "Grant AcrPull-only RBAC Administrator on $RegistryName to the dev and prod infra identities and publish registry variables. Continue?",
            'APIM 007 setup')) {
        throw 'Cancelled by user.'
    }

    Write-Section 'Registry role assignments'
    $acrPullCondition = New-RoleAssignmentCondition -RoleDefinitionIds @($Roles.AcrPull) -PrincipalType 'ServicePrincipal'
    foreach ($key in 'DevInfra', 'ProdInfra') {
        $identity = Get-ExistingIdentity -Definition $Identities[$key]
        Sync-RoleAssignment -Identity $identity -RoleName 'RbacAdministrator' -Scope $registry.id -Condition $acrPullCondition
    }

    Write-Section 'Registry variables'
    foreach ($environment in $RegistryVariableEnvironments) {
        Set-EnvironmentVariable -Environment $environment -Name 'REGISTRY_NAME' -Value $registry.name
        Set-EnvironmentVariable -Environment $environment -Name 'REGISTRY_LOGIN_SERVER' -Value $registry.loginServer
        Set-EnvironmentVariable -Environment $environment -Name 'REGISTRY_ID' -Value $registry.id
    }

    Write-Section 'Summary (non-secret)'
    Write-Info "Registry $($registry.name), login server $($registry.loginServer)"
    Write-Info 'Next: run infra-apim-007.yml with target=dev, then target=prod.'
}

#endregion

Assert-StageParameters
Assert-Tooling
Confirm-AzureContext
$script:RepoInfo = Get-RepositoryInfo
if ($WhatIfPreference) { Write-Host 'WhatIf: reads run, writes are only listed.' -ForegroundColor Yellow }

switch ($Stage) {
    'Initial' { Invoke-InitialStage }
    'PostRegistry' { Invoke-PostRegistryStage }
}
