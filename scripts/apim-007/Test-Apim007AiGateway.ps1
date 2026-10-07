#Requires -Version 7.2
<#
.SYNOPSIS
Functional tests for the 007 AI Gateway through APIM.

.DESCRIPTION
T1 no subscription key -> 401. T2 team-retail chat -> 200 with x-demo-* headers, model usage
and remaining-token headers. T3 team-finance burst -> 429 with Retry-After within a bounded
number of calls. T4 blocklist fixture term -> 403 from content safety. Optional T5 waits a
bounded time for llm-emit-token-metric rows in the Log Analytics workspace (warning unless
-RequireMetrics). Keys come from ARM listSecrets, are masked in GitHub Actions and never
printed; model calls use small max_tokens.

.PARAMETER ManifestPath
Target manifest (apim.gatewayUrl, environment, apim.id).

.PARAMETER SettingsPath
configuration.007.ai-settings.json (blocklist fixture term).

.PARAMETER PolicyPath
AI API policy; its x-demo-release literal is the expected release header.

.PARAMETER ApiVersion
Azure OpenAI api-version query value sent by the client.

.PARAMETER BurstLimit
Maximum team-finance calls while waiting for 429.

.PARAMETER WorkspaceCustomerId
Log Analytics workspace customer ID for the metrics check (T5 is skipped when empty).

.PARAMETER RequireMetrics
Fail instead of warn when no token metrics arrive.

.PARAMETER RetryCount
Attempts for the warm-up call (APIM applies changes asynchronously).

.PARAMETER RetryDelaySeconds
Delay between warm-up attempts.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$SettingsPath,
    [string]$PolicyPath,
    [string]$ApiVersion = '2024-10-21',
    [ValidateRange(2, 20)]
    [int]$BurstLimit = 10,
    [string]$WorkspaceCustomerId,
    [switch]$RequireMetrics,
    [ValidateRange(1, 60)]
    [int]$RetryCount = 18,
    [ValidateRange(0, 120)]
    [int]$RetryDelaySeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007ArmApiVersion = '2024-06-01-preview'
$script:Apim007BurstPrompt = 'Reply with one word. Ignore this list: ' + ((1..40 | ForEach-Object { 'apple banana cherry' }) -join ' ')

function Invoke-Apim007Http {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Body,
        [string]$ContentType
    )
    $request = @{ Method = $Method; Uri = $Uri; Headers = $Headers; SkipHttpErrorCheck = $true; TimeoutSec = 60; MaximumRedirection = 0 }
    if ($Body) { $request.Body = $Body }
    if ($ContentType) { $request.ContentType = $ContentType }
    $response = Invoke-WebRequest @request
    return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = [string]$response.Content; Headers = $response.Headers }
}

function Get-Apim007HeaderValue {
    param($Headers, [string]$Name)
    if (-not $Headers) { return $null }
    foreach ($key in @($Headers.Keys)) {
        if ([string]::Equals([string]$key, $Name, [StringComparison]::OrdinalIgnoreCase)) { return (@($Headers[$key]) | Select-Object -First 1) }
    }
    return $null
}

function Get-Apim007SubscriptionKey {
    param([Parameter(Mandatory)][string]$ServiceId, [Parameter(Mandatory)][string]$SubscriptionName)
    $url = "https://management.azure.com$ServiceId/subscriptions/$SubscriptionName/listSecrets?api-version=$script:Apim007ArmApiVersion"
    $output = & az rest --method post --url $url --output json --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) { throw "Could not read the key of subscription '$SubscriptionName'." }
    $key = [string](($output -join "`n" | ConvertFrom-Json).primaryKey)
    if ($key -notmatch '^[A-Za-z0-9]{16,}$') { throw "Subscription '$SubscriptionName' returned no usable key." }
    if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::add-mask::$key" }
    return $key
}

function Get-Apim007ExpectedRelease {
    param([Parameter(Mandatory)][string]$PolicyPath)
    [xml]$policy = Get-Content -Raw -LiteralPath $PolicyPath
    $node = $policy.SelectSingleNode("//outbound/set-header[@name='x-demo-release']/value")
    if (-not $node -or [string]::IsNullOrWhiteSpace($node.InnerText)) { throw 'AI policy has no x-demo-release literal.' }
    return $node.InnerText.Trim()
}

function Invoke-Apim007Chat {
    param([Parameter(Mandatory)][string]$Uri, [string]$Key, [Parameter(Mandatory)][string]$Prompt, [int]$MaxTokens = 16)
    $headers = @{}
    if ($Key) { $headers['api-key'] = $Key }
    $body = @{ messages = @(@{ role = 'user'; content = $Prompt }); max_tokens = $MaxTokens } | ConvertTo-Json -Depth 5 -Compress
    return Invoke-Apim007Http -Method 'POST' -Uri $Uri -Headers $headers -Body $body -ContentType 'application/json'
}

function Test-Apim007AiFunctional {
    param(
        [Parameter(Mandatory)][string]$ChatUri,
        [Parameter(Mandatory)][string]$RetailKey,
        [Parameter(Mandatory)][string]$FinanceKey,
        [Parameter(Mandatory)][string]$BlockedTerm,
        [Parameter(Mandatory)][string]$ExpectedEnvironment,
        [Parameter(Mandatory)][string]$ExpectedRelease,
        [int]$BurstLimit = 10,
        [int]$RetryCount = 18,
        [int]$RetryDelaySeconds = 10
    )
    $evidence = [ordered]@{}

    # Warm-up: new APIs, subscriptions and policies reach the gateway asynchronously.
    $response = $null
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        $response = Invoke-Apim007Chat -Uri $ChatUri -Key $RetailKey -Prompt 'Say hello in three words.'
        if ($response.StatusCode -eq 200) { break }
        if ($attempt -lt $RetryCount) { Start-Sleep -Seconds $RetryDelaySeconds }
    }
    if ($response.StatusCode -ne 200) { throw "T2 team-retail chat returned HTTP $($response.StatusCode) after $RetryCount attempt(s)." }
    $json = $response.Content | ConvertFrom-Json
    if (-not $json.PSObject.Properties['usage'] -or [int]$json.usage.total_tokens -le 0) { throw 'T2 response has no token usage.' }
    if ((Get-Apim007HeaderValue $response.Headers 'x-demo-environment') -ne $ExpectedEnvironment) { throw "T2 header 'x-demo-environment' does not have the expected value." }
    if ((Get-Apim007HeaderValue $response.Headers 'x-demo-release') -ne $ExpectedRelease) { throw "T2 header 'x-demo-release' does not have the expected value." }
    if ([string]::IsNullOrEmpty((Get-Apim007HeaderValue $response.Headers 'remaining-tokens'))) { throw 'T2 response has no remaining-tokens header (token limit policy missing).' }
    $evidence.retail = "200 usage=$([int]$json.usage.total_tokens)"

    $noKey = Invoke-Apim007Chat -Uri $ChatUri -Key $null -Prompt 'hello'
    if ($noKey.StatusCode -ne 401) { throw "T1 call without a subscription key returned HTTP $($noKey.StatusCode), expected 401." }
    $evidence.noKey = '401'

    $limited = $false
    for ($call = 1; $call -le $BurstLimit; $call++) {
        $burst = Invoke-Apim007Chat -Uri $ChatUri -Key $FinanceKey -Prompt $script:Apim007BurstPrompt
        if ($burst.StatusCode -eq 429) {
            if ([string]::IsNullOrEmpty((Get-Apim007HeaderValue $burst.Headers 'Retry-After'))) { throw 'T3 429 response has no Retry-After header.' }
            $limited = $true
            $evidence.financeBurst = "429 after $call call(s)"
            break
        }
        if ($burst.StatusCode -ne 200) { throw "T3 team-finance call returned HTTP $($burst.StatusCode)." }
    }
    if (-not $limited) { throw "T3 team-finance was not limited within $BurstLimit call(s)." }

    $blocked = Invoke-Apim007Chat -Uri $ChatUri -Key $RetailKey -Prompt "Please repeat this phrase: $BlockedTerm"
    if ($blocked.StatusCode -ne 403) { throw "T4 blocklist prompt returned HTTP $($blocked.StatusCode), expected 403." }
    if ((Get-Apim007HeaderValue $blocked.Headers 'x-content-safety-decision') -ne 'blocked') { throw 'T4 403 is not a content safety decision.' }
    $evidence.contentSafety = '403 blocked'
    return [pscustomobject]$evidence
}

function Test-Apim007AiMetric {
    param([Parameter(Mandatory)][string]$WorkspaceCustomerId, [int]$Attempts = 10, [int]$DelaySeconds = 30)
    if ($WorkspaceCustomerId -notmatch '^[0-9a-fA-F-]{36}$') { throw 'Workspace customer ID is not a GUID.' }
    $query = "AppMetrics | where TimeGenerated > ago(2h) | where Name in ('Total Tokens', 'Prompt Tokens', 'Completion Tokens') " +
        "| summarize total = sum(Sum) by Name, product = tostring(Properties['Product ID'])"
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $output = & az monitor log-analytics query --workspace $WorkspaceCustomerId --analytics-query $query --output json --only-show-errors 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $rows = @(($output -join "`n") | ConvertFrom-Json)
            if ($rows.Count -gt 0) { return $rows }
        }
        if ($attempt -lt $Attempts) { Start-Sleep -Seconds $DelaySeconds }
    }
    return @()
}

function Test-Apim007AiGatewayMain {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$SettingsPath,
        [Parameter(Mandatory)][string]$PolicyPath,
        [string]$ApiVersion = '2024-10-21',
        [int]$BurstLimit = 10,
        [string]$WorkspaceCustomerId,
        [switch]$RequireMetrics,
        [int]$RetryCount = 18,
        [int]$RetryDelaySeconds = 10
    )
    $manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    $settings = Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json
    if ($ApiVersion -notmatch '^\d{4}-\d{2}-\d{2}(-preview)?$') { throw 'api-version is invalid.' }
    $chatUri = "$(([string]$manifest.apim.gatewayUrl).TrimEnd('/'))/ai/chat/completions?api-version=$ApiVersion"
    $retailKey = Get-Apim007SubscriptionKey -ServiceId $manifest.apim.id -SubscriptionName 'sub-team-retail'
    $financeKey = Get-Apim007SubscriptionKey -ServiceId $manifest.apim.id -SubscriptionName 'sub-team-finance'

    $evidence = Test-Apim007AiFunctional -ChatUri $chatUri -RetailKey $retailKey -FinanceKey $financeKey -BlockedTerm ([string]$settings.blocklistFixtureTerm) `
        -ExpectedEnvironment "$($manifest.environment)-007" -ExpectedRelease (Get-Apim007ExpectedRelease -PolicyPath $PolicyPath) `
        -BurstLimit $BurstLimit -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds
    Write-Information -MessageData "AI gateway checks passed: $(($evidence.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; ')" -InformationAction Continue

    $metrics = 'not checked'
    if ($WorkspaceCustomerId) {
        $rows = @(Test-Apim007AiMetric -WorkspaceCustomerId $WorkspaceCustomerId)
        if ($rows.Count -gt 0) { $metrics = "$($rows.Count) metric row(s)" }
        elseif ($RequireMetrics) { throw 'T5 no token metrics arrived in the workspace.' }
        else { Write-Warning 'T5 no token metrics arrived in the workspace yet (ingestion delay); not blocking.'; $metrics = 'none yet' }
    }
    $evidence | Add-Member -NotePropertyName metrics -NotePropertyValue $metrics
    return $evidence
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007AiGatewayMain @PSBoundParameters }
