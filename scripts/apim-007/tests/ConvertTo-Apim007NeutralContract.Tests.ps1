BeforeAll {
    . (Join-Path $PSScriptRoot '../ConvertTo-Apim007NeutralContract.ps1')
    . (Join-Path $PSScriptRoot '../Get-Apim007WsdlInfo.ps1')
    $script:Contracts = Join-Path $PSScriptRoot 'fixtures/contracts'
}

Describe 'ConvertTo-Apim007NeutralContract' {
    It 'removes OpenAPI servers at document, path and operation level only' {
        $output = Join-Path $TestDrive 'openapi.json'
        $result = ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'openapi-captured.json') -OutputPath $output
        $result.Format | Should -Be 'OpenApiJson'
        $document = Get-Content -Raw $output | ConvertFrom-Json -AsHashtable
        $document.Contains('servers') | Should -BeFalse
        $document.paths['/WeatherForecast'].Contains('servers') | Should -BeFalse
        $document.paths['/WeatherForecast'].get.Contains('servers') | Should -BeFalse
        $document.components.schemas.WeatherForecast.properties.Contains('servers') | Should -BeTrue
        (Get-Content -Raw $output) | Should -Not -Match 'localhost'
    }

    It 'is deterministic' {
        $first = ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'openapi-captured.json') -OutputPath (Join-Path $TestDrive 'a.json')
        $second = ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'openapi-captured.json') -OutputPath (Join-Path $TestDrive 'b.json')
        $first.Sha256 | Should -Be $second.Sha256
    }

    It 'rejects an external OpenAPI reference' {
        { ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'openapi-external-ref.json') -OutputPath (Join-Path $TestDrive 'x.json') } |
            Should -Throw '*External OpenAPI reference*'
    }

    It 'sets every SOAP 1.1 and 1.2 address to the neutral URL' {
        $output = Join-Path $TestDrive 'service.wsdl'
        $result = ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'software-version-captured.wsdl') -OutputPath $output
        $result.Format | Should -Be 'Wsdl'
        $content = Get-Content -Raw $output
        $content | Should -Not -Match 'localhost'
        ([regex]::Matches($content, 'https://software-version\.invalid/SoftwareVersionService\.asmx')).Count | Should -Be 2
    }

    It 'rejects an external schemaLocation import' {
        { ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'software-version-external-import.wsdl') -OutputPath (Join-Path $TestDrive 'y.wsdl') } |
            Should -Throw '*External schema location*'
    }

    It 'rejects wsdl:import' {
        { ConvertTo-Apim007NeutralContractMain -InputPath (Join-Path $script:Contracts 'software-version-wsdl-import.wsdl') -OutputPath (Join-Path $TestDrive 'z.wsdl') } |
            Should -Throw '*wsdl:import is not allowed*'
    }
}

Describe 'Get-Apim007WsdlInfo' {
    It 'reads service, port, namespace and SOAPAction per operation' {
        $info = Get-Apim007WsdlInfoObject -WsdlPath (Join-Path $PSScriptRoot 'fixtures/repo/artifacts.007/apis/software-version/specification.wsdl')
        $info.TargetNamespace | Should -Be 'http://tempuri.org/'
        $info.ServiceName | Should -Be 'ISoftwareVersionService'
        $info.PortName | Should -Be 'BasicHttpBinding'
        $info.Address | Should -Be 'https://software-version.invalid/SoftwareVersionService.asmx'
        $operation = $info.Operations | Where-Object Name -EQ 'GetAllSoftwareVersions'
        $operation.SoapAction | Should -Be 'http://tempuri.org/ISoftwareVersionService/GetAllSoftwareVersions'
        $operation.InputElementName | Should -Be 'GetAllSoftwareVersions'
        $operation.InputElementNamespace | Should -Be 'http://tempuri.org/'
        @($info.Operations).Count | Should -Be 2
    }

    It 'emits JSON with -AsJson' {
        $json = Get-Apim007WsdlInfoMain -WsdlPath (Join-Path $script:Contracts 'software-version-captured.wsdl') -AsJson
        ($json | ConvertFrom-Json).Operations.Count | Should -Be 2
    }
}
