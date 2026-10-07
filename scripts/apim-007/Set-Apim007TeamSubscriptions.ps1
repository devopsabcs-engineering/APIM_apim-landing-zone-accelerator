#Requires -Version 7.2
<#
.SYNOPSIS
Ensures one active APIM subscription per 007 AI team product.

.DESCRIPTION
Idempotent ARM PUT of `sub-<product>` scoped to `/products/<product>` for every AI team product
listed in configuration.007.ai-settings.json (or passed with -Teams). Subscriptions
are outside the APIops bundle because their keys are secrets; this script never reads or
prints keys.

.PARAMETER ResourceGroup
APIM resource group.

.PARAMETER ServiceName
APIM service name.

.PARAMETER Teams
Team product names. Default: keys of `environments.<Environment>.teams` in the settings file.

.PARAMETER SettingsPath
Path to configuration.007.ai-settings.json (used when -Teams is not given).

.PARAMETER Environment
dev or prod (used with -SettingsPath).

.PARAMETER ApiVersion
ARM API version.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$ServiceName,
    [string[]]$Teams,
    [string]$SettingsPath,
    [ValidateSet('dev', 'prod')]
    [string]$Environment,
    [string]$ApiVersion = '2024-06-01-preview'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Apim007ArmJson {
    param([Parameter(Mandatory)][string]$Method, [Parameter(Mandatory)][string]$Url, $Body)
    $arguments = @('rest', '--method', $Method, '--url', $Url, '--output', 'json', '--only-show-errors')
    $bodyFile = $null
    try {
        if ($null -ne $Body) {
            $bodyFile = [IO.Path]::GetTempFileName()
            [IO.File]::WriteAllText($bodyFile, ($Body | ConvertTo-Json -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
            $arguments += @('--body', "@$bodyFile", '--headers', 'Content-Type=application/json')
        }
        $output = & az @arguments 2>$null
        if ($LASTEXITCODE -ne 0) { throw "az rest $Method failed for $([uri]::new($Url).AbsolutePath)." }
        if (-not $output) { return $null }
        return ($output -join "`n" | ConvertFrom-Json)
    }
    finally { if ($bodyFile) { Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue } }
}

function Get-Apim007TeamNames {
    param([string[]]$Teams, [string]$SettingsPath, [string]$Environment)
    if ($Teams) { return $Teams }
    if (-not $SettingsPath -or -not $Environment) { throw 'Pass -Teams, or -SettingsPath with -Environment.' }
    $settings = Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json
    return @($settings.environments.$Environment.teams.PSObject.Properties.Name)
}

function Set-Apim007TeamSubscriptionsMain {
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$ServiceName,
        [string[]]$Teams,
        [string]$SettingsPath,
        [string]$Environment,
        [string]$ApiVersion = '2024-06-01-preview'
    )
    $names = @(Get-Apim007TeamNames -Teams $Teams -SettingsPath $SettingsPath -Environment $Environment)
    if ($names.Count -eq 0) { throw 'No team products to subscribe.' }
    $serviceId = & az apim show --resource-group $ResourceGroup --name $ServiceName --query id -o tsv --only-show-errors
    if ($LASTEXITCODE -ne 0 -or -not $serviceId) { throw 'APIM service not found.' }
    $results = foreach ($team in $names) {
        if ($team -notmatch '^[a-z0-9][a-z0-9-]{1,78}$') { throw "Team product name '$team' is invalid." }
        $subscriptionName = "sub-$team"
        $body = @{ properties = @{ displayName = $subscriptionName; scope = "/products/$team"; state = 'active' } }
        $response = Invoke-Apim007ArmJson -Method put -Url "https://management.azure.com$($serviceId)/subscriptions/$($subscriptionName)?api-version=$ApiVersion" -Body $body
        if ($response.properties.state -ne 'active') { throw "Subscription $subscriptionName is not active." }
        [pscustomobject]@{ Product = $team; Subscription = $subscriptionName; State = $response.properties.state }
    }
    Write-Information -MessageData "Team subscriptions active: $(($results | ForEach-Object Subscription) -join ', ')" -InformationAction Continue
    return $results
}

if ($MyInvocation.InvocationName -ne '.') { Set-Apim007TeamSubscriptionsMain @PSBoundParameters }
