#Requires -Version 7.2
<#
.SYNOPSIS
Semantically compares a fresh APIops CLI extraction with the bundle, inventory and resolved overrides.

.DESCRIPTION
Exact mappings: API serviceUrl, backend url and named-value value must equal the overrides;
OpenAPI servers and WSDL addresses must equal the override URL or <gateway>/<api path>.
Generated operations (and any extracted specification) must match the inventory operations.
Product API links must equal the inventory and product groups must be empty (except the built-in administrators group). Generated files
under apis/*/operations and apis/*/schemas are tolerated; specification files in other formats
are validated for presence and ignored. Policies are compared after XML whitespace normalization.

Without -Project any drift fails. With -Project, changed apis/*/policy.xml and products/*/policy.xml
files are written to the projection directory and any other drift fails.

.PARAMETER ExtractionPath
Fresh extraction directory.

.PARAMETER BundlePath
Authoring bundle (artifacts.007).

.PARAMETER InventoryPath
configuration.007.expected-inventory.json.

.PARAMETER OverridesPath
Resolved override file used for the target environment.

.PARAMETER Project
Optional output directory for the authoring projection (changed API policies only).

.PARAMETER GatewayUrl
Optional gateway URL accepted as the OpenAPI server / WSDL address base.
#>
[CmdletBinding()]
param(
    [string]$ExtractionPath,
    [string]$BundlePath,
    [string]$InventoryPath,
    [string]$OverridesPath,
    [string]$Project,
    [string]$GatewayUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007IgnoredProperties = @{
    apis        = @('apiRevision', 'apiRevisionDescription', 'isCurrent', 'isOnline', 'authenticationSettings', 'subscriptionKeyParameterNames',
        'provisioningState', 'apiVersion', 'apiVersionDescription', 'apiVersionSetId', 'apiType', 'description', 'contact', 'license', 'termsOfServiceUrl', 'isAgent')
    backends    = @('provisioningState')
    namedValues = @('provisioningState', 'tags', 'keyVault')
    products    = @('provisioningState', 'terms', 'subscriptionsLimit', 'approvalRequired', 'authenticationType', 'application', 'groups')
}
$script:HttpMethods = @('get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace')

function Read-Apim007JsonFile {
    param([string]$Path)
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable)
}

function Read-Apim007XmlDocument {
    param([Parameter(Mandatory)][string]$Path, [bool]$PreserveWhitespace = $false)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.IgnoreComments = -not $PreserveWhitespace
    $document = [Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $PreserveWhitespace
    $document.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create((Resolve-Path -LiteralPath $Path).ProviderPath, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose() }
    return $document
}

function Get-Apim007NormalizedXml {
    param([string]$Path)
    return (Read-Apim007XmlDocument -Path $Path -PreserveWhitespace $false).DocumentElement.OuterXml
}

function ConvertTo-Apim007CanonicalJson {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
        # Null-valued properties (for example clientId or bearer) are server defaults, not configuration.
        $keys = [string[]]@($Value.Keys | Where-Object { $null -ne $Value[$_] })
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + ((@(foreach ($key in $keys) { (ConvertTo-Json -InputObject $key -Compress) + ':' + (ConvertTo-Apim007CanonicalJson $Value[$key]) })) -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return '[' + ((@(foreach ($item in $Value) { ConvertTo-Apim007CanonicalJson $item })) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Compress)
}

function Test-Apim007EmptyValue {
    param($Value)
    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) { return $Value.Length -eq 0 }
    if ($Value -is [System.Collections.IDictionary]) { return $Value.Count -eq 0 }
    if ($Value -is [System.Collections.ICollection]) { return $Value.Count -eq 0 }
    return $false
}

function Get-Apim007Properties {
    param([string]$Path)
    $json = Read-Apim007JsonFile -Path $Path
    if ($json -isnot [System.Collections.IDictionary] -or -not $json.ContainsKey('properties') -or $json.properties -isnot [System.Collections.IDictionary]) {
        throw "'$Path' has no properties object."
    }
    return $json.properties
}

function Compare-Apim007Property {
    param(
        [System.Collections.IDictionary]$Expected,
        [System.Collections.IDictionary]$Actual,
        [hashtable]$Overrides,
        [string[]]$IgnoredKeys,
        [string]$Context,
        [System.Collections.Generic.List[string]]$Drift
    )
    $effective = @{}
    foreach ($key in $Expected.Keys) { $effective[$key] = $Expected[$key] }
    foreach ($key in $Overrides.Keys) { $effective[$key] = $Overrides[$key] }
    foreach ($key in $effective.Keys) {
        if (-not $Actual.Contains($key)) {
            if ($effective[$key] -is [bool] -and -not $effective[$key]) { continue }
            if (Test-Apim007EmptyValue $effective[$key]) { continue }
            # APIM omits the default API type on read.
            if ($key -ceq 'type' -and $effective[$key] -ceq 'http') { continue }
            $Drift.Add("$Context property '$key' is missing.")
        }
        elseif ((ConvertTo-Apim007CanonicalJson $effective[$key]) -cne (ConvertTo-Apim007CanonicalJson $Actual[$key])) {
            $Drift.Add("$Context property '$key' differs from the expected value.")
        }
    }
    foreach ($key in $Actual.Keys) {
        if ($effective.ContainsKey($key) -or $key -in $IgnoredKeys -or (Test-Apim007EmptyValue $Actual[$key])) { continue }
        $Drift.Add("$Context has unexpected property '$key'.")
    }
}

function Get-Apim007ChildRelativePath {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | ForEach-Object { [IO.Path]::GetRelativePath($Root, $_.FullName) -replace '\\', '/' })
}

function Read-Apim007Overrides {
    param([string]$Path)
    $document = Read-Apim007JsonFile -Path $Path
    $map = @{}
    foreach ($section in 'apis', 'backends', 'namedValues') {
        if (-not $document.ContainsKey($section)) { continue }
        foreach ($item in @($document[$section])) {
            foreach ($property in $item.properties.Keys) { $map["$section.$($item.name).$property"] = [string]$item.properties[$property] }
        }
    }
    return $map
}

function Get-Apim007ResourceOverride {
    param([hashtable]$OverrideMap, [string]$Section, [string]$Name)
    $result = @{}
    foreach ($key in $OverrideMap.Keys) {
        $prefix = "$Section.$Name."
        if ($key.StartsWith($prefix, [StringComparison]::Ordinal)) { $result[$key.Substring($prefix.Length)] = $OverrideMap[$key] }
    }
    return $result
}

function Test-Apim007EndpointUrl {
    param([string]$Url, [string[]]$Allowed, [string]$ApiPath)
    $normalized = $Url.TrimEnd('/')
    if (@($Allowed | ForEach-Object { $_.TrimEnd('/') }) -contains $normalized) { return $true }
    if ($Allowed.Count -gt 1) { return $false }
    $uri = $null
    return ([Uri]::TryCreate($normalized, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -eq 'https' -and
        $uri.Host -notmatch '\.invalid$' -and $normalized.EndsWith("/$ApiPath", [StringComparison]::Ordinal))
}

function Get-Apim007ExtractedOperation {
    param([string]$ApiDirectory, [string]$ApiType)
    $operationsRoot = Join-Path $ApiDirectory 'operations'
    if (-not (Test-Path -LiteralPath $operationsRoot -PathType Container)) { return $null }
    $operations = foreach ($directory in Get-ChildItem -LiteralPath $operationsRoot -Directory) {
        $infoPath = Join-Path $directory.FullName 'operationInformation.json'
        if (-not (Test-Path -LiteralPath $infoPath -PathType Leaf)) { continue }
        $properties = Get-Apim007Properties -Path $infoPath
        if ($ApiType -eq 'soap') {
            if ($properties.Contains('displayName') -and $properties.displayName) { [string]$properties.displayName } else { $directory.Name }
        }
        else {
            $template = ([string]$properties.urlTemplate -split '\?', 2)[0]
            if (-not $template.StartsWith('/')) { $template = "/$template" }
            "$(([string]$properties.method).ToUpperInvariant()) $template"
        }
    }
    return , @($operations)
}

function Compare-Apim007OperationSet {
    param([string[]]$Expected, [string[]]$Actual, [string]$Context, [System.Collections.Generic.List[string]]$Drift)
    $expectedSorted = @($Expected | Sort-Object -Unique)
    $actualSorted = @($Actual | Sort-Object -Unique)
    if (($expectedSorted -join '|') -cne ($actualSorted -join '|') -or @($Actual).Count -ne $actualSorted.Count) {
        $Drift.Add("$Context operations [$($actualSorted -join ', ')] do not match the inventory [$($expectedSorted -join ', ')].")
    }
}

function Compare-Apim007ApiSpecification {
    param([string]$Path, [string]$ApiName, $ApiInventory, [string[]]$AllowedEndpoints, [System.Collections.Generic.List[string]]$Drift)
    $relative = "apis/$ApiName/$(Split-Path -Leaf $Path)"
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ((Get-Item -LiteralPath $Path).Length -eq 0) { $Drift.Add("$relative is empty."); return }
    if ($ApiInventory.type -eq 'soap') {
        if ($extension -notin '.wsdl', '.xml') { $Drift.Add("$relative conflicts with the SOAP API type."); return }
        $document = Read-Apim007XmlDocument -Path $Path
        foreach ($address in $document.SelectNodes("//*[local-name()='address']")) {
            if (-not (Test-Apim007EndpointUrl -Url $address.GetAttribute('location') -Allowed $AllowedEndpoints -ApiPath $ApiInventory.path)) {
                $Drift.Add("$relative endpoint address is not the expected environment URL.")
            }
        }
        $info = & (Join-Path $PSScriptRoot 'Get-Apim007WsdlInfo.ps1') -WsdlPath $Path
        Compare-Apim007OperationSet -Expected $ApiInventory.operations -Actual @($info.Operations.Name) -Context $relative -Drift $Drift
        return
    }
    if ($extension -in '.wsdl', '.xml') { $Drift.Add("$relative conflicts with the HTTP API type."); return }
    if ($extension -ne '.json') { return }
    $spec = Read-Apim007JsonFile -Path $Path
    if ($spec.Contains('servers')) {
        foreach ($server in @($spec.servers)) {
            if (-not (Test-Apim007EndpointUrl -Url ([string]$server.url) -Allowed $AllowedEndpoints -ApiPath $ApiInventory.path)) {
                $Drift.Add("$relative server URL is not the expected environment URL.")
            }
        }
    }
    $operations = foreach ($pathKey in @($(if ($spec.Contains('paths')) { $spec.paths.Keys } else { @() }))) {
        foreach ($method in $spec.paths[$pathKey].Keys) {
            if ($method -in $script:HttpMethods) { "$($method.ToUpperInvariant()) $pathKey" }
        }
    }
    Compare-Apim007OperationSet -Expected $ApiInventory.operations -Actual @($operations) -Context $relative -Drift $Drift
}

function Compare-Apim007ExtractionCore {
    param(
        [Parameter(Mandatory)][string]$ExtractionPath,
        [Parameter(Mandatory)][string]$BundlePath,
        [Parameter(Mandatory)][hashtable]$Inventory,
        [Parameter(Mandatory)][hashtable]$OverrideMap,
        [string]$GatewayUrl
    )
    $drift = [System.Collections.Generic.List[string]]::new()
    $policyChanges = [System.Collections.Generic.List[object]]::new()
    $resources = $Inventory.resources

    foreach ($entry in Get-ChildItem -LiteralPath $ExtractionPath -Force) {
        if ($entry.LinkType) { $drift.Add("Extraction contains a link: $($entry.Name)"); continue }
        if (-not $entry.PSIsContainer) { $drift.Add("Unexpected root file '$($entry.Name)'."); continue }
        if ($entry.Name -notin 'apis', 'backends', 'namedValues', 'products') { $drift.Add("Unexpected resource type '$($entry.Name)'.") }
    }

    $sections = @{
        apis        = @($resources.apis.Keys)
        backends    = @($resources.backends)
        namedValues = @($resources.namedValues)
        products    = @($resources.products.Keys)
    }
    foreach ($section in $sections.Keys) {
        $sectionRoot = Join-Path $ExtractionPath $section
        $actualNames = if (Test-Path -LiteralPath $sectionRoot) { @(Get-ChildItem -LiteralPath $sectionRoot -Force | ForEach-Object Name) } else { @() }
        foreach ($name in $actualNames) { if ($name -notin $sections[$section]) { $drift.Add("Unexpected $section entry '$name'.") } }
        foreach ($name in $sections[$section]) { if ($name -notin $actualNames) { $drift.Add("Missing $section entry '$name'.") } }
    }

    foreach ($apiName in $sections.apis) {
        $apiDirectory = Join-Path $ExtractionPath "apis/$apiName"
        if (-not (Test-Path -LiteralPath $apiDirectory)) { continue }
        $apiInventory = $resources.apis[$apiName]
        $context = "apis/$apiName"
        foreach ($relative in Get-Apim007ChildRelativePath -Root $apiDirectory) {
            if ($relative -in 'apiInformation.json', 'policy.xml' -or $relative -match '^specification\.[^/]+$' -or $relative -match '^(operations|schemas)/') { continue }
            $drift.Add("$context contains unexpected file '$relative'.")
        }
        $overrides = Get-Apim007ResourceOverride -OverrideMap $OverrideMap -Section 'apis' -Name $apiName
        $infoPath = Join-Path $apiDirectory 'apiInformation.json'
        if (-not (Test-Path -LiteralPath $infoPath)) { $drift.Add("$context/apiInformation.json is missing.") }
        else {
            Compare-Apim007Property -Expected (Get-Apim007Properties -Path (Join-Path $BundlePath "apis/$apiName/apiInformation.json")) `
                -Actual (Get-Apim007Properties -Path $infoPath) -Overrides $overrides -IgnoredKeys $script:Apim007IgnoredProperties.apis -Context $context -Drift $drift
        }

        $bundlePolicy = Join-Path $BundlePath "apis/$apiName/policy.xml"
        $extractedPolicy = Join-Path $apiDirectory 'policy.xml'
        $bundleHasPolicy = Test-Path -LiteralPath $bundlePolicy
        $extractHasPolicy = Test-Path -LiteralPath $extractedPolicy
        if ($bundleHasPolicy -and -not $extractHasPolicy) { $drift.Add("$context/policy.xml is missing.") }
        elseif ($extractHasPolicy -and -not $bundleHasPolicy) { $drift.Add("$context/policy.xml is not owned by the bundle.") }
        elseif ($extractHasPolicy -and (Get-Apim007NormalizedXml -Path $bundlePolicy) -cne (Get-Apim007NormalizedXml -Path $extractedPolicy)) {
            $policyChanges.Add([pscustomobject]@{ Api = $apiName; Relative = "apis/$apiName/policy.xml"; Path = $extractedPolicy })
        }

        $allowedEndpoints = @($(if ($overrides.ContainsKey('serviceUrl')) { $overrides.serviceUrl }))
        if ($GatewayUrl) { $allowedEndpoints += "$($GatewayUrl.TrimEnd('/'))/$($apiInventory.path)" }
        $extractedOperations = Get-Apim007ExtractedOperation -ApiDirectory $apiDirectory -ApiType $apiInventory.type
        $specifications = @(Get-ChildItem -LiteralPath $apiDirectory -File -Filter 'specification.*')
        if ($null -eq $extractedOperations -and $specifications.Count -eq 0) { $drift.Add("$context has neither generated operations nor a specification.") }
        if ($null -ne $extractedOperations) {
            Compare-Apim007OperationSet -Expected $apiInventory.operations -Actual $extractedOperations -Context "$context/operations" -Drift $drift
        }
        foreach ($specification in $specifications) {
            Compare-Apim007ApiSpecification -Path $specification.FullName -ApiName $apiName -ApiInventory $apiInventory -AllowedEndpoints $allowedEndpoints -Drift $drift
        }
    }

    $simpleSections = @(
        @{ Section = 'backends'; File = 'backendInformation.json' }
        @{ Section = 'namedValues'; File = 'namedValueInformation.json' }
    )
    foreach ($simple in $simpleSections) {
        foreach ($name in $sections[$simple.Section]) {
            $directory = Join-Path $ExtractionPath "$($simple.Section)/$name"
            if (-not (Test-Path -LiteralPath $directory)) { continue }
            $context = "$($simple.Section)/$name"
            foreach ($relative in Get-Apim007ChildRelativePath -Root $directory) {
                if ($relative -ne $simple.File) { $drift.Add("$context contains unexpected file '$relative'.") }
            }
            $actualPath = Join-Path $directory $simple.File
            if (-not (Test-Path -LiteralPath $actualPath)) { $drift.Add("$context/$($simple.File) is missing."); continue }
            Compare-Apim007Property -Expected (Get-Apim007Properties -Path (Join-Path $BundlePath "$context/$($simple.File)")) `
                -Actual (Get-Apim007Properties -Path $actualPath) -Overrides (Get-Apim007ResourceOverride -OverrideMap $OverrideMap -Section $simple.Section -Name $name) `
                -IgnoredKeys $script:Apim007IgnoredProperties[$simple.Section] -Context $context -Drift $drift
        }
    }

    foreach ($productName in $sections.products) {
        $directory = Join-Path $ExtractionPath "products/$productName"
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        $context = "products/$productName"
        foreach ($relative in Get-Apim007ChildRelativePath -Root $directory) {
            if ($relative -notin 'productInformation.json', 'apis.json', 'groups.json', 'policy.xml') { $drift.Add("$context contains unexpected file '$relative'.") }
        }
        $productInventory = $resources.products[$productName]
        $ownsPolicy = $productInventory -is [System.Collections.IDictionary] -and $productInventory.Contains('policy') -and [bool]$productInventory.policy
        $bundlePolicy = Join-Path $BundlePath "$context/policy.xml"
        $extractedPolicy = Join-Path $directory 'policy.xml'
        $extractHasPolicy = Test-Path -LiteralPath $extractedPolicy
        if ($ownsPolicy -and -not $extractHasPolicy) { $drift.Add("$context/policy.xml is missing.") }
        elseif ($extractHasPolicy -and -not $ownsPolicy) { $drift.Add("$context/policy.xml is not owned by the bundle.") }
        elseif ($extractHasPolicy -and (Get-Apim007NormalizedXml -Path $bundlePolicy) -cne (Get-Apim007NormalizedXml -Path $extractedPolicy)) {
            $policyChanges.Add([pscustomobject]@{ Api = $null; Relative = "$context/policy.xml"; Path = $extractedPolicy })
        }
        $infoPath = Join-Path $directory 'productInformation.json'
        if (-not (Test-Path -LiteralPath $infoPath)) { $drift.Add("$context/productInformation.json is missing.") }
        else {
            Compare-Apim007Property -Expected (Get-Apim007Properties -Path (Join-Path $BundlePath "$context/productInformation.json")) `
                -Actual (Get-Apim007Properties -Path $infoPath) -Overrides @{} -IgnoredKeys $script:Apim007IgnoredProperties.products -Context $context -Drift $drift
        }
        $apisPath = Join-Path $directory 'apis.json'
        $linkedApis = if (Test-Path -LiteralPath $apisPath) {
            @(foreach ($item in @(Read-Apim007JsonFile -Path $apisPath)) { if ($item -is [System.Collections.IDictionary]) { [string]$item.name } else { [string]$item } })
        }
        else { @() }
        if ((@($linkedApis | Sort-Object) -join ',') -cne (@($productInventory.apis | Sort-Object) -join ',')) {
            $drift.Add("$context API links do not match the inventory.")
        }
        $groupsPath = Join-Path $directory 'groups.json'
        $groups = if (Test-Path -LiteralPath $groupsPath) { @(Read-Apim007JsonFile -Path $groupsPath) | Where-Object { $null -ne $_ } } else { @() }
        # APIM links the built-in administrators group to every new product.
        $groups = @($groups | Where-Object { $name = if ($_ -is [System.Collections.IDictionary]) { [string]$_.name } else { [string]$_ }; $name -ne 'administrators' })
        if (@($groups).Count -gt 0 -or @($productInventory.groups).Count -gt 0) { $drift.Add("$context has product group links; expected none.") }
    }

    return [pscustomobject]@{ Drift = $drift.ToArray(); PolicyChanges = $policyChanges.ToArray() }
}

function Compare-Apim007ExtractionMain {
    param(
        [Parameter(Mandatory)][string]$ExtractionPath,
        [Parameter(Mandatory)][string]$BundlePath,
        [Parameter(Mandatory)][string]$InventoryPath,
        [Parameter(Mandatory)][string]$OverridesPath,
        [string]$Project,
        [string]$GatewayUrl
    )
    $inventory = Read-Apim007JsonFile -Path $InventoryPath
    $overrideMap = Read-Apim007Overrides -Path $OverridesPath
    $result = Compare-Apim007ExtractionCore -ExtractionPath $ExtractionPath -BundlePath $BundlePath -Inventory $inventory -OverrideMap $overrideMap -GatewayUrl $GatewayUrl

    $drift = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $result.Drift) { $drift.Add($item) }
    if (-not $Project) {
        foreach ($change in $result.PolicyChanges) { $drift.Add("$($change.Relative) differs from the bundle.") }
    }
    if ($drift.Count -gt 0) { throw ("Extraction comparison failed ({0} item(s)):`n - {1}" -f $drift.Count, ($drift -join "`n - ")) }

    $projected = @()
    if ($Project) {
        $null = New-Item -ItemType Directory -Path $Project -Force
        $projected = @(foreach ($change in $result.PolicyChanges) {
                $destination = Join-Path $Project $change.Relative
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
                Copy-Item -LiteralPath $change.Path -Destination $destination -Force
                $change.Relative
            })
    }
    Write-Information -MessageData "Extraction matches the inventory; $($result.PolicyChanges.Count) policy change(s)." -InformationAction Continue
    return [pscustomobject]@{ Matched = $true; PolicyChanges = $result.PolicyChanges.Count; ProjectedFiles = $projected }
}

if ($MyInvocation.InvocationName -ne '.') { Compare-Apim007ExtractionMain @PSBoundParameters }
