# You can write your azure powershell scripts inline here. 
# You can also pass predefined and custom variables to this script using arguments
Param( 

    #[PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "location")]        
    #[String]$location,
    
    [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "ResourceGroupNameApim")]
    [String]$ResourceGroupNameApim,

    #[PARAMETER(Mandatory = $True, Position = 2, HelpMessage = "zoneName")]
    #[String]$zoneName,

    #[PARAMETER(Mandatory = $True, Position = 3, HelpMessage = "appGatewayName")]        
    #[String]$appGatewayName,
    
    #[PARAMETER(Mandatory = $True, Position = 4, HelpMessage = "GitVersion.SemVer")]
    #[String]$GitVersionSemVer,

    [PARAMETER(Mandatory = $True, Position = 5, HelpMessage = "apimServiceName")]
    [String]$apimServiceName,

    [PARAMETER(Mandatory = $True, Position = 6, HelpMessage = "domainName")]        
    [String]$domainName,
    
    #[PARAMETER(Mandatory = $True, Position = 7, HelpMessage = "apimOrganization")]
    #[String]$apimOrganization,

    #[PARAMETER(Mandatory = $True, Position = 8, HelpMessage = "apimAdminEmail")]
    #[String]$apimAdminEmail,

    [PARAMETER(Mandatory = $True, Position = 9, HelpMessage = "pfxPassword")]        
    [String]$pfxPassword,
    
    [PARAMETER(Mandatory = $True, Position = 10, HelpMessage = "trustedrootcertsecureFIlePath")]
    [String]$trustedrootcertsecureFIlePath,

    [PARAMETER(Mandatory = $True, Position = 11, HelpMessage = "pfxApiTasksecureFIlePath")]
    [String]$pfxApiTasksecureFIlePath,

    [PARAMETER(Mandatory = $True, Position = 12, HelpMessage = "pfxPortalTasksecureFIlePath")]
    [String]$pfxPortalTasksecureFIlePath,

    [PARAMETER(Mandatory = $True, Position = 13, HelpMessage = "pfxManagementTasksecureFIlePath")]
    [String]$pfxManagementTasksecureFIlePath,

    [PARAMETER(Mandatory = $True, Position = 14, HelpMessage = "azureApplicationId")]
    [String]$azureApplicationId,

    [PARAMETER(Mandatory = $True, Position = 15, HelpMessage = "azureTenantId")]
    [String]$azureTenantId,

    [PARAMETER(Mandatory = $True, Position = 16, HelpMessage = "azureClientSecret")]
    [String]$azureClientSecret
)     

Write-Host post deploy only

Write-Host install az module

Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

$azurePassword = ConvertTo-SecureString "$azureClientSecret" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureApplicationId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

Write-Host "let us configure an app gateway for external access"

$gatewayHostname = "api.$domainName"                 # API gateway host
$portalHostname = "portal.$domainName"               # API developer portal host
$managementHostname = "management.$domainName"               # API management endpoint host

$gatewayCertPfxPath = "$pfxApiTasksecureFIlePath"
$portalCertPfxPath = "$pfxPortalTasksecureFIlePath"
$managementCertPfxPath = "$pfxManagementTasksecureFIlePath"
          
# should use seperate pws
$pw = "$pfxPassword"
$certGatewayPwd = ConvertTo-SecureString -String $pw  -AsPlainText -Force
$certPortalPwd = ConvertTo-SecureString -String $pw -AsPlainText -Force
$certManagementPwd = ConvertTo-SecureString -String $pw -AsPlainText -Force
          
# Path to trusted root CER file used in Application Gateway HTTP settings           
$trustedRootCertCerPath = "$trustedrootcertsecureFIlePath" # Full path to contoso.net trusted root .cer file
Get-Content $trustedRootCertCerPath

$gatewayHostnameConfig = New-AzApiManagementCustomHostnameConfiguration -Hostname $gatewayHostname `
    -HostnameType Proxy -PfxPath $gatewayCertPfxPath -PfxPassword $certGatewayPwd
$portalHostnameConfig = New-AzApiManagementCustomHostnameConfiguration -Hostname $portalHostname `
    -HostnameType DeveloperPortal -PfxPath $portalCertPfxPath -PfxPassword $certPortalPwd
$managementHostnameConfig = New-AzApiManagementCustomHostnameConfiguration -Hostname $managementHostname `
    -HostnameType Management -PfxPath $managementCertPfxPath -PfxPassword $certManagementPwd

$apimService = Get-AzApiManagement -ResourceGroupName $ResourceGroupNameApim -Name $apimServiceName

$apimService.ProxyCustomHostnameConfiguration = $gatewayHostnameConfig
$apimService.PortalCustomHostnameConfiguration = $portalHostnameConfig
$apimService.ManagementCustomHostnameConfiguration = $managementHostnameConfig

Set-AzApiManagement -InputObject $apimService

Write-Host After the application gateway deploys, confirm the health status of the API Management back ends in the portal or by running the following command

Get-AzApplicationGatewayBackendHealth -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim