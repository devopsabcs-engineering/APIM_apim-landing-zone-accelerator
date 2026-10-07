Describe 'Test-Apim007AiGateway' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../Test-Apim007AiGateway.ps1')
        function New-Response([int]$Status, [string]$Content = '{}', [hashtable]$Headers = @{}) {
            [pscustomobject]@{ StatusCode = $Status; Content = $Content; Headers = $Headers }
        }
        $script:Ok = New-Response 200 '{"usage":{"total_tokens":18}}' @{ 'x-demo-environment' = 'dev'; 'x-demo-release' = 'baseline-ai'; 'remaining-tokens' = '1982' }
        $script:AiArgs = @{ ChatUri = 'https://gw/ai/chat/completions?api-version=2024-10-21'; RetailKey = 'retailkey'; FinanceKey = 'financekey'
            BlockedTerm = 'blocked-term'; ExpectedEnvironment = 'dev'; ExpectedRelease = 'baseline-ai'; BurstLimit = 5; RetryCount = 2; RetryDelaySeconds = 0 }
    }

    BeforeEach {
        $script:FinanceCalls = 0
        $script:BlockedResponse = New-Response 403 '{}' @{ 'x-content-safety-decision' = 'blocked' }
        Mock Invoke-Apim007Http {
            $key = $Headers['api-key']
            if (-not $key) { return (New-Response 401) }
            if ($key -eq 'financekey') { $script:FinanceCalls++; if ($script:FinanceCalls -ge 3) { return (New-Response 429 '{}' @{ 'Retry-After' = '60' }) }; return $script:Ok }
            if ($Body -match 'blocked-term') { return $script:BlockedResponse }
            return $script:Ok
        }
    }

    It 'passes T1-T4 and reports evidence' {
        $a = $script:AiArgs; $result = Test-Apim007AiFunctional @a
        $result.retail | Should -Be '200 usage=18'
        $result.noKey | Should -Be '401'
        $result.financeBurst | Should -Be '429 after 3 call(s)'
        $result.contentSafety | Should -Be '403 blocked'
    }

    It 'fails when the blocklist prompt is not blocked' {
        $script:BlockedResponse = $script:Ok
        { $a = $script:AiArgs; Test-Apim007AiFunctional @a } | Should -Throw '*T4*expected 403*'
    }

    It 'fails when a 403 is not a content safety decision' {
        $script:BlockedResponse = New-Response 403
        { $a = $script:AiArgs; Test-Apim007AiFunctional @a } | Should -Throw '*T4 403 is not a content safety decision*'
    }

    It 'fails when the finance team is never limited' {
        $args2 = $script:AiArgs.Clone(); $args2.BurstLimit = 2
        { Test-Apim007AiFunctional @args2 } | Should -Throw '*T3*not limited within 2*'
    }

    It 'fails on the wrong release header' {
        $args2 = $script:AiArgs.Clone(); $args2.ExpectedRelease = 'ai-b'
        { Test-Apim007AiFunctional @args2 } | Should -Throw "*x-demo-release*"
    }

    It 'reads the expected release from the policy' {
        $policy = Join-Path $TestDrive 'policy.xml'
        '<policies><inbound /><backend /><outbound><set-header name="x-demo-release" exists-action="override"><value>baseline-ai</value></set-header></outbound><on-error /></policies>' | Set-Content -LiteralPath $policy
        Get-Apim007ExpectedRelease -PolicyPath $policy | Should -Be 'baseline-ai'
    }

    It 'rejects a non-GUID workspace id before querying' {
        { Test-Apim007AiMetric -WorkspaceCustomerId 'not-a-guid' } | Should -Throw '*not a GUID*'
    }
}

Describe 'Set-Apim007TeamSubscriptions' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../Set-Apim007TeamSubscriptions.ps1')
    }

    BeforeEach {
        Mock az { $global:LASTEXITCODE = 0; '/subscriptions/s/resourceGroups/rg/providers/Microsoft.ApiManagement/service/apim' }
        Mock Invoke-Apim007ArmJson { [pscustomobject]@{ properties = [pscustomobject]@{ state = 'active' } } }
    }

    It 'creates one product-scoped subscription per team from the settings file' {
        $settings = Join-Path $TestDrive 'settings.json'
        '{"environments":{"dev":{"teams":{"team-retail":{},"team-finance":{}}}}}' | Set-Content -LiteralPath $settings
        $result = Set-Apim007TeamSubscriptionsMain -ResourceGroup rg -ServiceName apim -SettingsPath $settings -Environment dev 6>$null
        @($result.Subscription) | Should -Be @('sub-team-retail', 'sub-team-finance')
        Should -Invoke Invoke-Apim007ArmJson -Times 1 -Exactly -ParameterFilter { $Url -match '/subscriptions/sub-team-retail\?' -and $Body.properties.scope -eq '/products/team-retail' }
        Should -Invoke Invoke-Apim007ArmJson -Times 0 -Exactly -ParameterFilter { $Url -match 'listSecrets' }
    }

    It 'rejects invalid team names' {
        { Set-Apim007TeamSubscriptionsMain -ResourceGroup rg -ServiceName apim -Teams 'Bad/Name' } | Should -Throw '*invalid*'
    }

    It 'fails when a subscription is not active' {
        Mock Invoke-Apim007ArmJson { [pscustomobject]@{ properties = [pscustomobject]@{ state = 'suspended' } } }
        { Set-Apim007TeamSubscriptionsMain -ResourceGroup rg -ServiceName apim -Teams 'team-retail' } | Should -Throw '*not active*'
    }
}

Describe 'Set-Apim007SafetyBlocklist' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../Set-Apim007SafetyBlocklist.ps1')
        $script:Settings = Join-Path $TestDrive 'ai-settings.json'
        '{"blocklistName":"apim007-demo","blocklistFixtureTerm":"apim007-blocked-demo-term"}' | Set-Content -LiteralPath $script:Settings
    }

    BeforeEach {
        Mock Get-Apim007CognitiveToken { 'token' }
        Mock Invoke-Apim007ContentSafety { $null }
    }

    It 'rejects endpoints that are not Cognitive Services hosts' -ForEach @(
        @{ Endpoint = 'http://cs-x.cognitiveservices.azure.com/' }
        @{ Endpoint = 'https://evil.example.com/' }
        @{ Endpoint = 'https://cs-x.cognitiveservices.azure.com.evil.com/' }
    ) {
        { Set-Apim007SafetyBlocklistMain -Endpoint $Endpoint -SettingsPath $script:Settings } | Should -Throw '*not an HTTPS Cognitive Services endpoint*'
        Should -Invoke Get-Apim007CognitiveToken -Times 0 -Exactly
    }

    It 'creates the blocklist and then upserts the fixture term' {
        $result = Set-Apim007SafetyBlocklistMain -Endpoint 'https://cs-x.cognitiveservices.azure.com/' -SettingsPath $script:Settings 6>$null
        $result.BlocklistName | Should -Be 'apim007-demo'
        Should -Invoke Invoke-Apim007ContentSafety -Times 1 -Exactly -ParameterFilter { $Method -eq 'Patch' -and $Uri -match '/blocklists/apim007-demo\?' }
        Should -Invoke Invoke-Apim007ContentSafety -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' -and $Uri -match ':addOrUpdateBlocklistItems\?' -and $Body.blocklistItems[0].text -eq 'apim007-blocked-demo-term' }
    }
}
