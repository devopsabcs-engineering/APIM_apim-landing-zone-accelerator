BeforeAll {
    . (Join-Path $PSScriptRoot 'Apim007TestHelpers.ps1')
    . (Join-Path $PSScriptRoot '../New-Apim007Overrides.ps1')
    $script:ManifestFixture = Join-Path $PSScriptRoot 'fixtures/manifests/manifest.dev.json'
    $script:InventoryFixture = Join-Path $PSScriptRoot 'fixtures/repo/configuration.007.expected-inventory.json'

    function Get-TestManifest {
        return (Get-Content -Raw -LiteralPath $script:ManifestFixture | ConvertFrom-Json)
    }
    function Get-TestInventory {
        return (Get-Content -Raw -LiteralPath $script:InventoryFixture | ConvertFrom-Json -AsHashtable)
    }
}

Describe 'New-Apim007Overrides' {
    It 'produces the exact override JSON for dev' {
        $outputPath = Join-Path $TestDrive 'overrides.dev.json'
        $result = New-Apim007OverridesMain -ManifestPath $script:ManifestFixture -InventoryPath $script:InventoryFixture -OutputPath $outputPath
        $expected = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/overrides/expected.dev.json') | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress
        $actual = Get-Content -Raw $outputPath | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress
        $actual | Should -BeExactly $expected
        $result.Sha256 | Should -Be (Get-FileHash $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        (Get-Content -Raw $outputPath) | Should -Not -Match "`r"
    }

    It 'writes to RUNNER_TEMP by default' {
        $previous = $env:RUNNER_TEMP
        try {
            $env:RUNNER_TEMP = Join-Path $TestDrive 'runner-temp'
            $null = New-Item -ItemType Directory -Path $env:RUNNER_TEMP -Force
            $result = New-Apim007OverridesMain -ManifestPath $script:ManifestFixture -InventoryPath $script:InventoryFixture
            $result.Path | Should -Be (Join-Path $env:RUNNER_TEMP 'apim007-overrides-dev.json')
        }
        finally { $env:RUNNER_TEMP = $previous }
    }

    It 'rejects a legacy 006 backend host' {
        $manifest = Get-TestManifest
        $manifest.backends.apps.weather.defaultHostName = 'app-weather-dev-006.azurewebsites.net'
        $manifest.backends.apps.weather.httpsBaseUrl = 'https://app-weather-dev-006.azurewebsites.net'
        { New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory) } | Should -Throw '*legacy 005/006*'
    }

    It 'rejects gateway self-routing' {
        $manifest = Get-TestManifest
        $manifest.backends.apps.weather.defaultHostName = 'apim-demo-007-dev.azure-api.net'
        $manifest.backends.apps.weather.httpsBaseUrl = 'https://apim-demo-007-dev.azure-api.net'
        { New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory) } | Should -Throw '*APIM gateway itself*'
    }

    It 'rejects a missing value' {
        $manifest = Get-TestManifest
        $manifest.backends.apps.'software-version'.httpsBaseUrl = ''
        { New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory) } | Should -Throw '*has no value*'
    }

    It 'rejects a non-HTTPS value' {
        $manifest = Get-TestManifest
        $manifest.backends.apps.weather.httpsBaseUrl = 'http://app-apim007-weather-dev.azurewebsites.net'
        { New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory) } | Should -Throw '*not an absolute HTTPS URL*'
    }

    It 'rejects a sentinel value' {
        $manifest = Get-TestManifest
        $manifest.backends.apps.weather.httpsBaseUrl = 'https://weather.invalid'
        { New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory) } | Should -Throw '*sentinel*'
    }

    It 'rejects an unknown target' {
        $inventory = Get-TestInventory
        $inventory.overrideTargets += 'apis.weather.description'
        { New-Apim007OverrideDocument -Manifest (Get-TestManifest) -Inventory $inventory } | Should -Throw "*Unknown override target 'apis.weather.description'*"
    }

    It 'rejects a target that is not in the inventory resources' {
        $inventory = Get-TestInventory
        $inventory.resources.backends = @('weather-backend')
        { New-Apim007OverrideDocument -Manifest (Get-TestManifest) -Inventory $inventory } | Should -Throw '*does not match an inventory resource*'
    }
}

Describe 'Get-Apim007TargetManifest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../Get-Apim007TargetManifest.ps1')
        $script:Sub = '22222222-2222-2222-2222-222222222222'
        $script:Tenant = '11111111-1111-1111-1111-111111111111'

        function New-TestOutput {
            param([hashtable]$Values)
            $outputs = [ordered]@{}
            foreach ($key in $Values.Keys) { $outputs[$key] = @{ type = 'String'; value = $Values[$key] } }
            return $outputs
        }
        $apimRg = "/subscriptions/$script:Sub/resourceGroups/rg-apim-demo-007-dev-apim"
        $backendRg = "/subscriptions/$script:Sub/resourceGroups/rg-apim-demo-007-dev-backends"
        $script:ApimDeployment = @{
            id = "$apimRg/providers/Microsoft.Resources/deployments/apim007-apim-dev"; name = 'apim007-apim-dev'
            properties = @{ provisioningState = 'Succeeded'; correlationId = 'c1'; outputs = (New-TestOutput @{
                        apimName = 'apim-demo-007-dev'; apimId = "$apimRg/providers/Microsoft.ApiManagement/service/apim-demo-007-dev"
                        apimGatewayUrl = 'https://apim-demo-007-dev.azure-api.net'; location = 'canadacentral'; resourceGroupId = $apimRg
                    })
            }
        } | ConvertTo-Json -Depth 10
        $script:BackendDeployment = @{
            id = "$backendRg/providers/Microsoft.Resources/deployments/apim007-backends-dev"; name = 'apim007-backends-dev'
            properties = @{ provisioningState = 'Succeeded'; correlationId = 'c2'; outputs = (New-TestOutput @{
                        weatherAppName = 'app-apim007-weather-dev'; weatherAppId = "$backendRg/providers/Microsoft.Web/sites/app-apim007-weather-dev"
                        weatherDefaultHostName = 'app-apim007-weather-dev.azurewebsites.net'; weatherHttpsBaseUrl = 'https://app-apim007-weather-dev.azurewebsites.net'
                        weatherPrincipalId = 'p1'
                        softwareVersionAppName = 'app-apim007-soap-dev'; softwareVersionAppId = "$backendRg/providers/Microsoft.Web/sites/app-apim007-soap-dev"
                        softwareVersionDefaultHostName = 'app-apim007-soap-dev.azurewebsites.net'; softwareVersionHttpsBaseUrl = 'https://app-apim007-soap-dev.azurewebsites.net'
                        softwareVersionPrincipalId = 'p2'
                    })
            }
        } | ConvertTo-Json -Depth 10
        $script:Tags = '{"apimDemo":"007","environment":"dev","owner":"apim-demo-007"}'
    }

    BeforeEach {
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'account' } -MockWith { "{`"tenantId`":`"$script:Tenant`",`"id`":`"$script:Sub`"}" }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'deployment' -and $Arguments -contains 'apim007-apim-dev' } -MockWith { $script:ApimDeployment }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'deployment' -and $Arguments -contains 'apim007-backends-dev' } -MockWith { $script:BackendDeployment }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'deployment' -and $Arguments -contains 'apim007-ai-dev' } -MockWith { $null }
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'resource' } -MockWith { $script:Tags }
    }

    It 'builds a canonical manifest that drives the override generator' {
        $path = Join-Path $TestDrive 'manifest.json'
        $result = Get-Apim007TargetManifestMain -Environment dev -ExpectedTenantId $script:Tenant -ExpectedSubscriptionId $script:Sub -OutputPath $path
        $result.Sha256 | Should -Match '^[a-f0-9]{64}$'
        $manifest = Get-Content -Raw $path | ConvertFrom-Json
        $manifest.apim.gatewayUrl | Should -Be 'https://apim-demo-007-dev.azure-api.net'
        $manifest.backends.apps.'software-version'.httpsBaseUrl | Should -Be 'https://app-apim007-soap-dev.azurewebsites.net'
        $document = New-Apim007OverrideDocument -Manifest $manifest -Inventory (Get-TestInventory)
        $document.namedValues[0].properties.value | Should -Be 'dev-007'
        Should -Invoke Invoke-Az -ParameterFilter { $Arguments[0] -eq 'deployment' -and $Arguments -contains 'show' } -Times 3 -Exactly
        $manifest.PSObject.Properties['ai'] | Should -BeNullOrEmpty
    }

    It 'rejects a tenant mismatch' {
        { Get-Apim007TargetManifestMain -Environment dev -ExpectedTenantId 'other' -ExpectedSubscriptionId $script:Sub -OutputPath (Join-Path $TestDrive 'm.json') } |
            Should -Throw '*tenant does not match*'
    }

    It 'rejects resources without the 007 tags' {
        Mock Invoke-Az -ParameterFilter { $Arguments[0] -eq 'resource' } -MockWith { '{"apimDemo":"006","environment":"dev"}' }
        { Get-Apim007TargetManifestMain -Environment dev -ExpectedTenantId $script:Tenant -ExpectedSubscriptionId $script:Sub -OutputPath (Join-Path $TestDrive 'm.json') } |
            Should -Throw '*not tagged apimDemo=007*'
    }
}
