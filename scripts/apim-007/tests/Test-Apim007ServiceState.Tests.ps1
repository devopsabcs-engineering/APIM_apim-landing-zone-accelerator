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
        $script:DiagnosticProperties = '{"loggerId":"/loggers/apimlogger","metrics":true}'
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match 'diagnostics/applicationinsights' } -MockWith { "{`"properties`":$script:DiagnosticProperties}" }
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

    It 'fails when the metrics diagnostic changed' {
        $script:DiagnosticProperties = '{"loggerId":"/loggers/apimlogger","metrics":false}'
        { Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline } | Should -Throw "*'diagnostics/applicationinsights' changed*"
    }

    It 'checks every inventory product against its own API list' {
        $inventory = Join-Path $TestDrive 'inventory.json'
        '{"resources":{"products":{"demo":{"apis":["weather","software-version"]},"team-retail":{"apis":["ai-gateway"]}}}}' | Set-Content -LiteralPath $inventory
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match 'products/team-retail/apis\?' } -MockWith { '{"value":[{"name":"ai-gateway"}]}' }
        (Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline -InventoryPath $inventory 6>$null).Passed | Should -BeTrue
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'rest' -and ($Arguments -join ' ') -match 'products/team-retail/apis\?' } -MockWith { '{"value":[]}' }
        { Test-Apim007ServiceStateMain -ResourceGroup rg -ServiceName apim -Mode Verify -BaselinePath $script:Baseline -InventoryPath $inventory } | Should -Throw "*Product 'team-retail' API links*"
    }
}
