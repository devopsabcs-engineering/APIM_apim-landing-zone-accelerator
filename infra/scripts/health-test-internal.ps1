Param( 

    [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "location")]        
    [String]$location,
    
    [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "ResourceGroupNameApim")]
    [String]$ResourceGroupNameApim,

    [PARAMETER(Mandatory = $True, Position = 2, HelpMessage = "zoneName")]
    [String]$zoneName,

    [PARAMETER(Mandatory = $True, Position = 3, HelpMessage = "appGatewayName")]        
    [String]$appGatewayName,
    
    #[PARAMETER(Mandatory = $True, Position = 4, HelpMessage = "GitVersion.SemVer")]
    #[String]$GitVersionSemVer,

    [PARAMETER(Mandatory = $True, Position = 5, HelpMessage = "apimServiceName")]
    [String]$apimServiceName,

    [PARAMETER(Mandatory = $True, Position = 6, HelpMessage = "domainName")]        
    [String]$domainName,
    
    [PARAMETER(Mandatory = $True, Position = 7, HelpMessage = "apimOrganization")]
    [String]$apimOrganization,

    [PARAMETER(Mandatory = $True, Position = 8, HelpMessage = "apimAdminEmail")]
    [String]$apimAdminEmail,

    [PARAMETER(Mandatory = $True, Position = 9, HelpMessage = "pfxPassword")]        
    [String]$pfxPassword,
    
    # [PARAMETER(Mandatory = $True, Position = 10, HelpMessage = "trustedrootcertsecureFIlePath")]
    # [String]$trustedrootcertsecureFIlePath,

    # [PARAMETER(Mandatory = $True, Position = 11, HelpMessage = "pfxApiTasksecureFIlePath")]
    # [String]$pfxApiTasksecureFIlePath,

    # [PARAMETER(Mandatory = $True, Position = 12, HelpMessage = "pfxPortalTasksecureFIlePath")]
    # [String]$pfxPortalTasksecureFIlePath,

    # [PARAMETER(Mandatory = $True, Position = 13, HelpMessage = "pfxManagementTasksecureFIlePath")]
    # [String]$pfxManagementTasksecureFIlePath,

    [PARAMETER(Mandatory = $True, Position = 14, HelpMessage = "azureApplicationId")]
    [String]$azureApplicationId,

    [PARAMETER(Mandatory = $True, Position = 15, HelpMessage = "azureTenantId")]
    [String]$azureTenantId,

    [PARAMETER(Mandatory = $True, Position = 16, HelpMessage = "azureClientSecret")]
    [String]$azureClientSecret
)     

Write-Host generate hosts file

Get-Content C:\Windows\System32\drivers\etc\hosts

Copy-Item -Force C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts.default


$azurePassword = ConvertTo-SecureString "$azureClientSecret" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureApplicationId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

#Write-Host After the application gateway deploys, confirm the health status of the API Management back ends in the portal or by running the following command
          
#Get-AzApplicationGatewayBackendHealth -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim


$gatewayHostname = "api.$domainName"                 # API gateway host
$portalHostname = "portal.$domainName"               # API developer portal host
$managementHostname = "management.$domainName"               # API management endpoint host

$appGw = Get-AzApplicationGateway -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim

echo $appGw

$apimService = Get-AzApiManagement -ResourceGroupName $ResourceGroupNameApim -Name $apimServiceName 

echo $apimService


$publicip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupNameApim -name "publicIP01"

echo app gateway public ip $publicip.IpAddress

echo apim public ip addresses $apimService.PublicIPAddresses[0]
echo apim private ip addresses $apimService.PrivateIPAddresses[0]

echo $publicip.IpAddress $gatewayHostname > C:\Windows\System32\drivers\etc\hosts.external
echo $publicip.IpAddress $portalHostname >> C:\Windows\System32\drivers\etc\hosts.external
echo $publicip.IpAddress $managementHostname >> C:\Windows\System32\drivers\etc\hosts.external

echo external host file
Get-Content C:\Windows\System32\drivers\etc\hosts.external


echo $apimService.PrivateIPAddresses[0] $gatewayHostname > C:\Windows\System32\drivers\etc\hosts.internal
echo $apimService.PrivateIPAddresses[0] $portalHostname >> C:\Windows\System32\drivers\etc\hosts.internal
echo $apimService.PrivateIPAddresses[0] $managementHostname >> C:\Windows\System32\drivers\etc\hosts.internal

echo internal host file
Get-Content C:\Windows\System32\drivers\etc\hosts.internal