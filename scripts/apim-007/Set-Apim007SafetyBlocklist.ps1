#Requires -Version 7.2
<#
.SYNOPSIS
Creates or updates the 007 Content Safety text blocklist and its fixture term.

.DESCRIPTION
Idempotent data-plane calls to the Content Safety account: PATCH the blocklist, then
addOrUpdateBlocklistItems with the fixture term from configuration.007.ai-settings.json.
Uses an Entra token for https://cognitiveservices.azure.com held in memory only; the
caller needs Cognitive Services User on the account. Local (key) auth is never used.

.PARAMETER Endpoint
Content Safety account endpoint (https://<name>.cognitiveservices.azure.com/).

.PARAMETER SettingsPath
Path to configuration.007.ai-settings.json.

.PARAMETER ApiVersion
Content Safety data-plane API version.
#>
[CmdletBinding()]
param(
    [string]$Endpoint,
    [string]$SettingsPath,
    [string]$ApiVersion = '2024-09-01'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Apim007CognitiveToken {
    $token = & az account get-access-token --resource 'https://cognitiveservices.azure.com' --query accessToken -o tsv --only-show-errors
    if ($LASTEXITCODE -ne 0 -or -not $token) { throw 'Could not get a Cognitive Services access token.' }
    return $token
}

function Invoke-Apim007ContentSafety {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)]$Body,
        [string]$ContentType = 'application/json'
    )
    $json = $Body | ConvertTo-Json -Depth 5 -Compress
    $headers = @{ Authorization = "Bearer $Token" }
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType $ContentType -Body $json
        }
        catch {
            $status = [int]($_.Exception.Response.StatusCode ?? 0)
            # Fresh role assignments take a few minutes to reach the data plane.
            if ($status -in 401, 403, 429 -and $attempt -lt 6) { Start-Sleep -Seconds (20 * $attempt); continue }
            throw "Content Safety $Method $([uri]::new($Uri).AbsolutePath) failed (HTTP $status)."
        }
    }
}

function Set-Apim007SafetyBlocklistMain {
    param(
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$SettingsPath,
        [string]$ApiVersion = '2024-09-01'
    )
    $uri = [uri]$Endpoint
    if ($uri.Scheme -ne 'https' -or $uri.Host -notmatch '^[a-z0-9-]+\.cognitiveservices\.azure\.com$') {
        throw "Endpoint '$Endpoint' is not an HTTPS Cognitive Services endpoint."
    }
    $settings = Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json
    $name = [string]$settings.blocklistName
    $term = [string]$settings.blocklistFixtureTerm
    if ($name -notmatch '^[a-z0-9][a-z0-9-]{2,63}$') { throw "Blocklist name '$name' is invalid." }
    if ([string]::IsNullOrWhiteSpace($term)) { throw 'Blocklist fixture term is empty.' }

    $base = "https://$($uri.Host)/contentsafety/text/blocklists/$name"
    $token = Get-Apim007CognitiveToken
    $null = Invoke-Apim007ContentSafety -Method Patch -Uri "$($base)?api-version=$ApiVersion" -Token $token `
        -ContentType 'application/merge-patch+json' -Body @{ description = 'APIM 007 demo blocklist (deterministic content safety test)' }
    $null = Invoke-Apim007ContentSafety -Method Post -Uri "$($base):addOrUpdateBlocklistItems?api-version=$ApiVersion" -Token $token `
        -Body @{ blocklistItems = @(@{ text = $term; description = 'APIM 007 fixture term' }) }
    Write-Information -MessageData "Blocklist '$name' is present with its fixture term." -InformationAction Continue
    return [pscustomobject]@{ BlocklistName = $name; Endpoint = $uri.Host }
}

if ($MyInvocation.InvocationName -ne '.') { Set-Apim007SafetyBlocklistMain @PSBoundParameters }
