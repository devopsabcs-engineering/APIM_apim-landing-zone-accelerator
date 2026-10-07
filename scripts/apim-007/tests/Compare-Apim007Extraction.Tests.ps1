BeforeAll {
    . (Join-Path $PSScriptRoot 'Apim007TestHelpers.ps1')
    . (Join-Path $PSScriptRoot '../Compare-Apim007Extraction.ps1')
    $script:OverridesPath = Join-Path $PSScriptRoot 'fixtures/overrides/expected.dev.json'
}

Describe 'Compare-Apim007Extraction' {
    BeforeEach {
        $script:Repo = New-Apim007TestRepository -Path (Join-Path $TestDrive "repo-$([guid]::NewGuid().ToString('N'))")
        $script:Extraction = New-Apim007TestExtraction -BundlePath $script:Repo.BundlePath -Destination (Join-Path $TestDrive "extract-$([guid]::NewGuid().ToString('N'))") -OverridesPath $script:OverridesPath
        $script:ProjectPath = Join-Path $TestDrive "project-$([guid]::NewGuid().ToString('N'))"
        $script:CompareArgs = @{
            ExtractionPath = $script:Extraction
            BundlePath     = $script:Repo.BundlePath
            InventoryPath  = $script:Repo.InventoryPath
            OverridesPath  = $script:OverridesPath
            GatewayUrl     = $script:Apim007TestGatewayUrl
        }
    }

    It 'accepts an unchanged extraction' {
        $result = Compare-Apim007ExtractionMain @script:CompareArgs 6>$null
        $result.Matched | Should -BeTrue
        $result.PolicyChanges | Should -Be 0
    }

    It 'produces an empty projection for an unchanged extraction' {
        $result = Compare-Apim007ExtractionMain @script:CompareArgs -Project $script:ProjectPath 6>$null
        @($result.ProjectedFiles).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $script:ProjectPath -Recurse -File).Count | Should -Be 0
    }

    It 'ignores whitespace-only policy differences' {
        $policy = Join-Path $script:Extraction 'apis/weather/policy.xml'
        $compact = (Get-Content -Raw $policy) -replace '>\s+<', '><'
        [IO.File]::WriteAllText($policy, "  $compact  ")
        $result = Compare-Apim007ExtractionMain @script:CompareArgs 6>$null
        $result.PolicyChanges | Should -Be 0
    }

    It 'projects only a changed API policy' {
        $policy = Join-Path $script:Extraction 'apis/weather/policy.xml'
        (Get-Content -Raw $policy).Replace('baseline-a', 'candidate-b') | Set-Content -Path $policy -NoNewline
        $result = Compare-Apim007ExtractionMain @script:CompareArgs -Project $script:ProjectPath 6>$null
        @($result.ProjectedFiles) | Should -Be @('apis/weather/policy.xml')
        $files = @(Get-ChildItem -LiteralPath $script:ProjectPath -Recurse -File | ForEach-Object { [IO.Path]::GetRelativePath($script:ProjectPath, $_.FullName) -replace '\\', '/' })
        $files | Should -Be @('apis/weather/policy.xml')
        (Get-Content -Raw (Join-Path $script:ProjectPath 'apis/weather/policy.xml')) | Should -Match 'candidate-b'
    }

    It 'fails on a policy change without -Project' {
        $policy = Join-Path $script:Extraction 'apis/weather/policy.xml'
        (Get-Content -Raw $policy).Replace('baseline-a', 'candidate-b') | Set-Content -Path $policy -NoNewline
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw '*apis/weather/policy.xml differs*'
    }

    It 'fails on serviceUrl drift even with -Project' {
        Set-Apim007TestProperty -Path (Join-Path $script:Extraction 'apis/weather/apiInformation.json') -Properties @{ serviceUrl = 'https://app-weather-dev-006.azurewebsites.net' }
        { Compare-Apim007ExtractionMain @script:CompareArgs -Project $script:ProjectPath } | Should -Throw "*apis/weather property 'serviceUrl' differs*"
        Test-Path -LiteralPath $script:ProjectPath | Should -BeFalse
    }

    It 'fails on backend url drift' {
        Set-Apim007TestProperty -Path (Join-Path $script:Extraction 'backends/weather-backend/backendInformation.json') -Properties @{ url = 'https://weather.invalid' }
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw "*backends/weather-backend property 'url' differs*"
    }

    It 'fails on named value drift' {
        Set-Apim007TestProperty -Path (Join-Path $script:Extraction 'namedValues/demo-environment/namedValueInformation.json') -Properties @{ value = 'prod-007' }
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw "*namedValues/demo-environment property 'value' differs*"
    }

    It 'fails on nonempty product groups' {
        [IO.File]::WriteAllText((Join-Path $script:Extraction 'products/demo/groups.json'), '[{"name":"developers"}]')
        { Compare-Apim007ExtractionMain @script:CompareArgs -Project $script:ProjectPath } | Should -Throw '*product group links*'
    }

    It 'fails on a missing product API link' {
        [IO.File]::WriteAllText((Join-Path $script:Extraction 'products/demo/apis.json'), '[{"name":"weather"}]')
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw '*API links do not match*'
    }

    It 'fails on an unexpected generated operation' {
        New-Apim007TestOperation -ApiDirectory (Join-Path $script:Extraction 'apis/weather') -Name 'post-weatherforecast' -Properties @{ method = 'POST'; urlTemplate = '/WeatherForecast' }
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw '*apis/weather/operations operations*'
    }

    It 'fails on an unexpected API' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Extraction 'apis/echo-api')
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw "*Unexpected apis entry 'echo-api'*"
    }

    It 'fails on an unexpected resource type' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Extraction 'loggers/apimlogger') -Force
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw "*Unexpected resource type 'loggers'*"
    }

    It 'fails when the OpenAPI server is not the environment URL' {
        $specPath = Join-Path $script:Extraction 'apis/weather/specification.json'
        $spec = Get-Content -Raw $specPath | ConvertFrom-Json -AsHashtable
        $spec.servers = @(@{ url = 'https://apim-dev-006.azure-api.net/weather' })
        Write-Apim007TestJson -Path $specPath -Value $spec
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw '*server URL is not the expected environment URL*'
    }

    It 'fails when the WSDL address is not the environment URL' {
        $wsdlPath = Join-Path $script:Extraction 'apis/software-version/specification.wsdl'
        $wsdl = (Get-Content -Raw $wsdlPath).Replace("$($script:Apim007TestGatewayUrl)/software-version", 'https://software-version.invalid/SoftwareVersionService.asmx')
        [IO.File]::WriteAllText($wsdlPath, $wsdl)
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw '*endpoint address is not the expected environment URL*'
    }

    It 'fails on an unexpected API property' {
        Set-Apim007TestProperty -Path (Join-Path $script:Extraction 'apis/weather/apiInformation.json') -Properties @{ subscriptionRequired = $true }
        { Compare-Apim007ExtractionMain @script:CompareArgs } | Should -Throw "*property 'subscriptionRequired' differs*"
    }
}
