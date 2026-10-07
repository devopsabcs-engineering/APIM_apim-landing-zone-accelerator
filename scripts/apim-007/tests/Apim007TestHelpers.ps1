Set-StrictMode -Version Latest

$script:Apim007ScriptRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$script:Apim007FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
$script:Apim007TestGatewayUrl = 'https://apim-demo-007-dev.azure-api.net'

function Write-Apim007TestJson {
    param([string]$Path, $Value)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}

function Update-Apim007TestFilterHash {
    param([Parameter(Mandatory)][string]$RepositoryPath)
    $inventoryPath = Join-Path $RepositoryPath 'configuration.007.expected-inventory.json'
    $inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -AsHashtable
    $inventory.ownershipFilter.sha256 = (Get-FileHash -LiteralPath (Join-Path $RepositoryPath $inventory.ownershipFilter.path) -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Apim007TestJson -Path $inventoryPath -Value $inventory
}

function New-Apim007TestRepository {
    param([Parameter(Mandatory)][string]$Path)
    $null = New-Item -ItemType Directory -Path $Path -Force
    Copy-Item -Path (Join-Path $script:Apim007FixtureRoot 'repo/*') -Destination $Path -Recurse -Force
    $scriptsDestination = Join-Path $Path 'scripts/apim-007'
    $null = New-Item -ItemType Directory -Path $scriptsDestination -Force
    Copy-Item -Path (Join-Path $script:Apim007ScriptRoot '*.ps1') -Destination $scriptsDestination
    Update-Apim007TestFilterHash -RepositoryPath $Path
    return [pscustomobject]@{
        Root          = $Path
        BundlePath    = Join-Path $Path 'artifacts.007'
        InventoryPath = Join-Path $Path 'configuration.007.expected-inventory.json'
        FilterPath    = Join-Path $Path 'configuration.007.ownership.yaml'
    }
}

function Set-Apim007TestProperty {
    param([string]$Path, [hashtable]$Properties)
    $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
    foreach ($key in $Properties.Keys) { $document.properties[$key] = $Properties[$key] }
    Write-Apim007TestJson -Path $Path -Value $document
}

function New-Apim007TestOperation {
    param([string]$ApiDirectory, [string]$Name, [hashtable]$Properties)
    Write-Apim007TestJson -Path (Join-Path $ApiDirectory "operations/$Name/operationInformation.json") -Value @{ properties = $Properties }
}

function New-Apim007TestExtraction {
    param(
        [Parameter(Mandatory)][string]$BundlePath,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$OverridesPath,
        [string]$GatewayUrl = $script:Apim007TestGatewayUrl
    )
    $null = New-Item -ItemType Directory -Path $Destination -Force
    Copy-Item -Path (Join-Path $BundlePath '*') -Destination $Destination -Recurse -Force
    $overrides = Get-Content -Raw -LiteralPath $OverridesPath | ConvertFrom-Json -AsHashtable
    foreach ($api in $overrides.apis) {
        Set-Apim007TestProperty -Path (Join-Path $Destination "apis/$($api.name)/apiInformation.json") -Properties @{
            serviceUrl = $api.properties.serviceUrl; isCurrent = $true; apiRevision = '1'
            subscriptionKeyParameterNames = @{ header = 'Ocp-Apim-Subscription-Key'; query = 'subscription-key' }
        }
    }
    foreach ($backend in $overrides.backends) {
        Set-Apim007TestProperty -Path (Join-Path $Destination "backends/$($backend.name)/backendInformation.json") -Properties @{ url = $backend.properties.url }
    }
    foreach ($namedValue in $overrides.namedValues) {
        Set-Apim007TestProperty -Path (Join-Path $Destination "namedValues/$($namedValue.name)/namedValueInformation.json") -Properties @{ value = $namedValue.properties.value; tags = @() }
    }

    $weather = Join-Path $Destination 'apis/weather'
    New-Apim007TestOperation -ApiDirectory $weather -Name 'get-weatherforecast' -Properties @{ displayName = 'GetWeatherForecast'; method = 'GET'; urlTemplate = '/WeatherForecast' }
    New-Apim007TestOperation -ApiDirectory $weather -Name 'get-api-version' -Properties @{ displayName = 'Version'; method = 'GET'; urlTemplate = '/api/Version' }
    Write-Apim007TestJson -Path (Join-Path $weather 'schemas/generated-schema/schemaInformation.json') -Value @{ properties = @{ contentType = 'application/vnd.oai.openapi.components+json' } }
    $spec = Get-Content -Raw -LiteralPath (Join-Path $weather 'specification.json') | ConvertFrom-Json -AsHashtable
    $spec['servers'] = @(@{ url = "$GatewayUrl/weather" })
    Write-Apim007TestJson -Path (Join-Path $weather 'specification.json') -Value $spec
    [IO.File]::WriteAllText((Join-Path $weather 'specification.yaml'), "openapi: 3.0.1`n", [Text.UTF8Encoding]::new($false))

    $soap = Join-Path $Destination 'apis/software-version'
    New-Apim007TestOperation -ApiDirectory $soap -Name 'getsoftwareversion' -Properties @{ displayName = 'GetSoftwareVersion'; method = 'POST'; urlTemplate = '/?soapAction=http://tempuri.org/ISoftwareVersionService/GetSoftwareVersion' }
    New-Apim007TestOperation -ApiDirectory $soap -Name 'getallsoftwareversions' -Properties @{ displayName = 'GetAllSoftwareVersions'; method = 'POST'; urlTemplate = '/?soapAction=http://tempuri.org/ISoftwareVersionService/GetAllSoftwareVersions' }
    $wsdlPath = Join-Path $soap 'specification.wsdl'
    $wsdl = (Get-Content -Raw -LiteralPath $wsdlPath).Replace('https://software-version.invalid/SoftwareVersionService.asmx', "$GatewayUrl/software-version")
    [IO.File]::WriteAllText($wsdlPath, $wsdl, [Text.UTF8Encoding]::new($false))

    [IO.File]::WriteAllText((Join-Path $Destination 'products/demo/groups.json'), '[]', [Text.UTF8Encoding]::new($false))
    return $Destination
}
