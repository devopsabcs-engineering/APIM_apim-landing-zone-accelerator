BeforeAll {
    . (Join-Path $PSScriptRoot '../Test-Apim007ServiceState.ps1')
    $script:ServiceId = '/subscriptions/s/resourceGroups/rg/providers/Microsoft.ApiManagement/service/apim'
}

Describe 'Test-Apim007ServiceState' {
    BeforeEach {
        $script:LoggerProperties = '{"loggerType":"applicationInsights","credentials":{"instrumentationKey":"{{Logger-Credentials}}"}}'
        $script:Groups = '{"value":[]}'
        $script:Apis = '{"value":[{"name":"weather"},{"name":"software-version"}]}'
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'apim' } -MockWith { "{`"id`":`"$script:ServiceId`"}" }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match 'namedValues/instrumentationKey' } -MockWith { '{"properties":{"displayName":"instrumentationKey","secret":true}}' }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match 'loggers/apimlogger' } -MockWith { "{`"properties`":$script:LoggerProperties}" }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match '/groups\?' } -MockWith { $script:Groups }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match '/apis\?' } -MockWith { $script:Apis }
        $script:Baseline = Join-Path $TestDrive "baseline-$([guid]::NewGuid().ToString('N')).json"
        $null = Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Capture -BaselinePath $script:Baseline 6>$null
    }

    It 'passes when nothing changed' {
        (Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline 6>$null).Passed | Should -BeTrue
    }

    It 'fails when a protected logger changed' {
        $script:LoggerProperties = '{"loggerType":"applicationInsights","credentials":{"instrumentationKey":"{{Other}}"}}'
        { Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline } | Should -Throw "*'loggers/apimlogger' changed*"
    }

    It 'fails when the product has group links' {
        $script:Groups = '{"value":[{"name":"developers"}]}'
        { Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline } | Should -Throw '*group links: developers*'
    }

    It 'fails when the product API links differ' {
        $script:Apis = '{"value":[{"name":"weather"},{"name":"echo-api"},{"name":"software-version"}]}'
        { Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline } | Should -Throw '*API links*'
    }

    It 'never writes protected property values to the baseline' {
        (Get-Content -Raw $script:Baseline) | Should -Not -Match 'Logger-Credentials'
    }
}
