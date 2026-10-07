#Requires -Version 7.2
<#
.SYNOPSIS
Reads service, port, target namespace and per-operation SOAPAction from a WSDL 1.1 file.

.PARAMETER WsdlPath
WSDL file to parse (DTD processing and external resolution are disabled).

.PARAMETER AsJson
Emit compressed JSON instead of an object.
#>
[CmdletBinding()]
param(
    [string]$WsdlPath,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Apim007XmlDocument {
    param([Parameter(Mandatory)][string]$Path, [bool]$PreserveWhitespace = $true)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = [Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $PreserveWhitespace
    $document.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create((Resolve-Path -LiteralPath $Path).ProviderPath, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose() }
    return $document
}

function Get-Apim007LocalName {
    param([string]$QualifiedName)
    if ($QualifiedName -notmatch '^([A-Za-z_][\w.\-]*:)?([A-Za-z_][\w.\-]*)$') { throw "Invalid WSDL QName '$QualifiedName'." }
    return $Matches[2]
}

function Get-Apim007WsdlInfoObject {
    param([Parameter(Mandatory)][string]$WsdlPath)
    $document = Read-Apim007XmlDocument -Path $WsdlPath
    $ns = [Xml.XmlNamespaceManager]::new($document.NameTable)
    $ns.AddNamespace('wsdl', 'http://schemas.xmlsoap.org/wsdl/')
    $ns.AddNamespace('soap', 'http://schemas.xmlsoap.org/wsdl/soap/')
    $definitions = $document.SelectSingleNode('/wsdl:definitions', $ns)
    if (-not $definitions) { throw 'Not a WSDL 1.1 definitions document.' }

    $service = $null
    $port = $null
    foreach ($candidateService in $document.SelectNodes('/wsdl:definitions/wsdl:service', $ns)) {
        foreach ($candidatePort in $candidateService.SelectNodes('wsdl:port', $ns)) {
            if ($candidatePort.SelectSingleNode('soap:address', $ns)) { $service = $candidateService; $port = $candidatePort; break }
        }
        if ($port) { break }
    }
    if (-not $port) { throw 'WSDL has no SOAP 1.1 port.' }

    $bindingName = Get-Apim007LocalName -QualifiedName $port.GetAttribute('binding')
    $binding = $document.SelectSingleNode("/wsdl:definitions/wsdl:binding[@name='$bindingName']", $ns)
    if (-not $binding) { throw "Binding '$bindingName' not found." }
    $portTypeName = Get-Apim007LocalName -QualifiedName $binding.GetAttribute('type')
    $portType = $document.SelectSingleNode("/wsdl:definitions/wsdl:portType[@name='$portTypeName']", $ns)
    if (-not $portType) { throw "PortType '$portTypeName' not found." }

    $operations = foreach ($bindingOperation in $binding.SelectNodes('wsdl:operation', $ns)) {
        $name = Get-Apim007LocalName -QualifiedName $bindingOperation.GetAttribute('name')
        $soapOperation = $bindingOperation.SelectSingleNode('soap:operation', $ns)
        $soapAction = if ($soapOperation) { $soapOperation.GetAttribute('soapAction') } else { '' }
        $portOperation = $portType.SelectSingleNode("wsdl:operation[@name='$name']", $ns)
        if (-not $portOperation) { throw "Operation '$name' is missing from portType '$portTypeName'." }
        $inputElement = $portOperation.SelectSingleNode('wsdl:input', $ns)
        if (-not $inputElement) { throw "Operation '$name' has no input message." }
        $messageName = Get-Apim007LocalName -QualifiedName $inputElement.GetAttribute('message')
        $part = $document.SelectSingleNode("/wsdl:definitions/wsdl:message[@name='$messageName']/wsdl:part", $ns)
        if (-not $part -or -not $part.GetAttribute('element')) { throw "Operation '$name' input is not document/literal with an element part." }
        $elementQName = $part.GetAttribute('element')
        $prefix = if ($elementQName.Contains(':')) { $elementQName.Split(':')[0] } else { '' }
        $elementNamespace = $part.GetNamespaceOfPrefix($prefix)
        [pscustomobject]@{
            Name                  = $name
            SoapAction            = $soapAction
            InputElementName      = Get-Apim007LocalName -QualifiedName $elementQName
            InputElementNamespace = $elementNamespace
        }
    }
    if (-not $operations) { throw 'WSDL binding has no operations.' }

    return [pscustomobject]@{
        TargetNamespace = $definitions.GetAttribute('targetNamespace')
        ServiceName     = $service.GetAttribute('name')
        PortName        = $port.GetAttribute('name')
        BindingName     = $bindingName
        Address         = $port.SelectSingleNode('soap:address', $ns).GetAttribute('location')
        SoapVersion     = '1.1'
        Operations      = @($operations)
    }
}

function Get-Apim007WsdlInfoMain {
    param([Parameter(Mandatory)][string]$WsdlPath, [switch]$AsJson)
    $info = Get-Apim007WsdlInfoObject -WsdlPath $WsdlPath
    if ($AsJson) { return ($info | ConvertTo-Json -Depth 5 -Compress) }
    return $info
}

if ($MyInvocation.InvocationName -ne '.') { Get-Apim007WsdlInfoMain @PSBoundParameters }
