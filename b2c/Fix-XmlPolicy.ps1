param(
    [Parameter(HelpMessage = "Personal Access Token with read/write permissions to variable groups and secret files.")]
    [string] $PrimaryStorageEndpoint,
      
    [Parameter(HelpMessage = "Full organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $backendApiApplicationClientId,
      
    [Parameter(HelpMessage = "Project name (follows organization name in the URL).")]
    [string] $b2cpolicy_well_known_openid,

    [string] $apimDeveloperPortal = "",  
    [string] $XmlPolicyTemplatePath = "",
    [string] $XmlRootPolicyTemplatePath = "",
    [string] $environmentName
)

# .\Fix-XmlPolicy.ps1 -PrimaryStorageEndpoint "https://stwebxfqkisuspuoei.z9.web.core.windows.net/" `
#     -backendApiApplicationClientId 0e227db0-e411-40ff-9538-a4e52b717b78 `
#     -b2cpolicy_well_known_openid "https://testekb2c008.b2clogin.com/testekb2c008.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_frontendapp_dev_signupandsignin" `
#     -environmentName dev -XmlPolicyTemplatePath .\APIM\policies\policies.template.xml `
#     -apimDeveloperPortal "https://apim-bcpcue6zklgaw.developer.azure-api.net" `
#     -XmlRootPolicyTemplatePath .\APIM\policies\policiesRoot.template.xml

# .\Fix-XmlPolicy.ps1 -PrimaryStorageEndpoint "https://stweb2sclfr3rhz56c.z9.web.core.windows.net/" `
#     -backendApiApplicationClientId b1fcab55-fcec-4cc0-b577-4db8c54cee23 `
#     -b2cpolicy_well_known_openid "https://testekb2c008.b2clogin.com/testekb2c008.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_frontendapp_prd_signupandsignin" `
#     -environmentName prd -XmlPolicyTemplatePath .\APIM\policies\policies.template.xml `
#     -apimDeveloperPortal "https://apim-257jlvys5ho6o.developer.azure-api.net" `
#     -XmlRootPolicyTemplatePath .\APIM\policies\policiesRoot.template.xml

$XmlPolicy = Get-Content -Path $XmlPolicyTemplatePath -Raw

$XmlPolicy = $XmlPolicy.Replace("#{b2cPrimaryStorageEndpoint}#", $PrimaryStorageEndpoint)
$XmlPolicy = $XmlPolicy.Replace("#{b2cbackend-api-application-client-id}#", $backendApiApplicationClientId)
$XmlPolicy = $XmlPolicy.Replace("#{b2cpolicy-well-known-openid}#", $b2cpolicy_well_known_openid)

$XmlPolicyPath = $XmlPolicyTemplatePath.Replace("template", $environmentName)

Set-Content -Value $XmlPolicy -Path $XmlPolicyPath

$XmlRootPolicy = Get-Content -Path $XmlRootPolicyTemplatePath -Raw

$XmlRootPolicy = $XmlRootPolicy.Replace("#{b2cPrimaryStorageEndpoint}#", $PrimaryStorageEndpoint)
$XmlRootPolicy = $XmlRootPolicy.Replace("#{apimDeveloperPortal}#", $apimDeveloperPortal)

$XmlRootPolicyPath = $XmlRootPolicyTemplatePath.Replace("template", $environmentName)

Set-Content -Value $XmlRootPolicy -Path $XmlRootPolicyPath