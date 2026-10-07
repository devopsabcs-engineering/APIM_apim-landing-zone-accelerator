BeforeAll {
    . (Join-Path $PSScriptRoot '../Test-Apim007Backend.ps1')
    . (Join-Path $PSScriptRoot '../Test-Apim007Gateway.ps1')
    . (Join-Path $PSScriptRoot '../Get-Apim007WsdlInfo.ps1')
    $script:WsdlPath = Join-Path $PSScriptRoot 'fixtures/repo/artifacts.007/apis/software-version/specification.wsdl'
    $script:PolicyPath = Join-Path $PSScriptRoot 'fixtures/repo/artifacts.007/apis/weather/policy.xml'
    $script:ManifestPath = Join-Path $PSScriptRoot 'fixtures/manifests/manifest.dev.json'
    $script:WsdlInfo = Get-Apim007WsdlInfoObject -WsdlPath $script:WsdlPath
    $script:Version = '1.2.3.4'

    function New-SoapResponse {
        param([string[]]$Versions)
        $items = ($Versions | ForEach-Object { "<a:SoftwareVersion><a:SemanticVersion>$_</a:SemanticVersion></a:SoftwareVersion>" }) -join ''
        return "<s:Envelope xmlns:s=`"http://schemas.xmlsoap.org/soap/envelope/`"><s:Body><R xmlns=`"http://tempuri.org/`" xmlns:a=`"urn:x`">$items</R></s:Body></s:Envelope>"
    }

    function New-FakeResponse {
        param([string]$Uri, [hashtable]$Headers, [string]$Version = $script:Version, [hashtable]$ResponseHeaders = @{})
        if ($Uri -like '*/WeatherForecast') {
            $items = 1..5 | ForEach-Object { @{ date = '2026-10-0' + $_; temperatureC = 10 + $_; summary = 'Mild'; version = $Version } }
            return [pscustomobject]@{ StatusCode = 200; Content = ($items | ConvertTo-Json); Headers = $ResponseHeaders }
        }
        if ($Uri -like '*/api/Version') { return [pscustomobject]@{ StatusCode = 200; Content = $Version; Headers = $ResponseHeaders } }
        if ($Headers.SOAPAction -like '*GetAllSoftwareVersions*') {
            return [pscustomobject]@{ StatusCode = 200; Content = (New-SoapResponse @('1.0.0.0', '1.0.1.0', '1.0.2.0')); Headers = $ResponseHeaders }
        }
        return [pscustomobject]@{ StatusCode = 200; Content = (New-SoapResponse @($Version)); Headers = $ResponseHeaders }
    }
}

Describe 'Test-Apim007Backend' {
    It 'builds a SOAP 1.1 envelope from the WSDL' {
        $operation = $script:WsdlInfo.Operations | Where-Object Name -EQ 'GetSoftwareVersion'
        [xml]$envelope = New-Apim007SoapEnvelope -Operation $operation
        $envelope.DocumentElement.NamespaceURI | Should -Be 'http://schemas.xmlsoap.org/soap/envelope/'
        $body = $envelope.DocumentElement.FirstChild.FirstChild
        $body.LocalName | Should -Be 'GetSoftwareVersion'
        $body.NamespaceURI | Should -Be 'http://tempuri.org/'
    }

    It 'passes when every functional check succeeds and sends SOAP headers' {
        Mock Invoke-Apim007Http { New-FakeResponse -Uri $Uri -Headers $Headers }
        { Invoke-Apim007FunctionalCheck -WeatherBaseUrl 'https://w.example' -SoapServiceUrl 'https://s.example/SoftwareVersionService.asmx' -WsdlInfo $script:WsdlInfo -ExpectedVersion $script:Version } |
            Should -Not -Throw
        Should -Invoke Invoke-Apim007Http -Times 2 -Exactly -ParameterFilter {
            $ContentType -eq 'text/xml; charset=utf-8' -and $Headers.SOAPAction -match '^"http://tempuri.org/ISoftwareVersionService/Get'
        }
    }

    It 'fails on a version mismatch' {
        Mock Invoke-Apim007Http { New-FakeResponse -Uri $Uri -Headers $Headers -Version '9.9.9.9' }
        { Invoke-Apim007FunctionalCheck -WeatherBaseUrl 'https://w.example' -SoapServiceUrl 'https://s.example' -WsdlInfo $script:WsdlInfo -ExpectedVersion $script:Version } |
            Should -Throw '*version*'
    }

    It 'fails on a SOAP Fault' {
        Mock Invoke-Apim007Http {
            if ($Method -eq 'POST') { return [pscustomobject]@{ StatusCode = 200; Content = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault /></s:Body></s:Envelope>'; Headers = @{} } }
            New-FakeResponse -Uri $Uri -Headers $Headers
        }
        { Invoke-Apim007FunctionalCheck -WeatherBaseUrl 'https://w.example' -SoapServiceUrl 'https://s.example' -WsdlInfo $script:WsdlInfo -ExpectedVersion $script:Version } |
            Should -Throw '*SOAP Fault*'
    }

    It 'retries a bounded number of times' {
        Mock Invoke-Apim007Http { [pscustomobject]@{ StatusCode = 503; Content = ''; Headers = @{} } }
        { Test-Apim007BackendMain -WeatherBaseUrl 'https://w.example' -SoapServiceUrl 'https://s.example' -WsdlPath $script:WsdlPath -ExpectedVersion $script:Version -RetryCount 3 -RetryDelaySeconds 0 3>$null 6>$null } |
            Should -Throw '*failed after 3 attempts*'
        Should -Invoke Invoke-Apim007Http -Times 3 -Exactly
    }
}

Describe 'Test-Apim007Gateway' {
    It 'reads the literal release from the candidate policy' {
        Get-Apim007PolicyRelease -PolicyPath $script:PolicyPath | Should -Be 'baseline-a'
    }

    It 'derives gateway URLs and expected headers from the manifest' {
        $manifest = Get-Content -Raw $script:ManifestPath | ConvertFrom-Json
        $parameters = Get-Apim007GatewayCheckParameter -Manifest $manifest -WsdlPath $script:WsdlPath -ExpectedVersion $script:Version -PolicyPath $script:PolicyPath
        $parameters.WeatherBaseUrl | Should -Be 'https://apim-demo-007-dev.azure-api.net/weather'
        $parameters.SoapServiceUrl | Should -Be 'https://apim-demo-007-dev.azure-api.net/software-version'
        $parameters.ExpectedWeatherHeaders['x-demo-environment'] | Should -Be 'dev-007'
        $parameters.ExpectedWeatherHeaders['x-demo-release'] | Should -Be 'baseline-a'
        $parameters.ExpectedSoapHeaders['x-demo-backend-host'] | Should -Be 'app-apim007-soap-dev.azurewebsites.net'
    }

    It 'lets an explicit expected release override the policy (simulated dev gate failure)' {
        $manifest = Get-Content -Raw $script:ManifestPath | ConvertFrom-Json
        $parameters = Get-Apim007GatewayCheckParameter -Manifest $manifest -WsdlPath $script:WsdlPath -ExpectedVersion $script:Version -PolicyPath $script:PolicyPath -ExpectedRelease 'simulated-failure'
        $parameters.ExpectedWeatherHeaders['x-demo-release'] | Should -Be 'simulated-failure'
    }

    It 'fails when a gateway header does not match' {
        $headers = @{ 'x-demo-environment' = 'dev-007'; 'x-demo-release' = 'baseline-a'; 'x-demo-backend-host' = 'app-apim007-weather-dev.azurewebsites.net' }
        Mock Invoke-Apim007Http { New-FakeResponse -Uri $Uri -Headers $Headers -ResponseHeaders @{ 'X-Demo-Environment' = @('prod-007'); 'x-demo-release' = @('baseline-a') } }
        { Invoke-Apim007FunctionalCheck -WeatherBaseUrl 'https://g.example/weather' -SoapServiceUrl 'https://g.example/software-version' -WsdlInfo $script:WsdlInfo `
                -ExpectedVersion $script:Version -ExpectedWeatherHeaders $headers } | Should -Throw "*header 'x-demo-environment'*"
    }

    It 'rejects a gateway that equals a backend host' {
        { Get-Apim007GatewayCheckParameter -GatewayUrl 'https://app.example' -WsdlPath $script:WsdlPath -ExpectedVersion $script:Version -ExpectedEnvironment 'dev-007' `
                -ExpectedRelease 'r' -ExpectedWeatherBackendHost 'app.example' -ExpectedSoapBackendHost 'soap.example' } | Should -Throw '*must differ*'
    }
}
