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
    [String]$azureClientSecret,
    [PARAMETER(Mandatory = $True, Position = 17, HelpMessage = "appGatewayPublicIpName")]
    [String]$appGatewayPublicIpName
)     

Write-Host generate hosts file

Write-Host but first we quickly check private dns zones

$gatewayHostname = "api.$domainName"                 # API gateway host
$portalHostname = "portal.$domainName"               # API developer portal host
$managementHostname = "management.$domainName"               # API management endpoint host

Write-Host "do nslookup thrice..."

nslookup.exe $gatewayHostname
nslookup.exe $portalHostname
nslookup.exe $managementHostname


Get-Content C:\Windows\System32\drivers\etc\hosts

Copy-Item -Force C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts.default


$azurePassword = ConvertTo-SecureString "$azureClientSecret" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureApplicationId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

#Write-Host After the application gateway deploys, confirm the health status of the API Management back ends in the portal or by running the following command
          
#Get-AzApplicationGatewayBackendHealth -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim




$appGw = Get-AzApplicationGateway -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim

Write-Host $appGw

$apimService = Get-AzApiManagement -ResourceGroupName $ResourceGroupNameApim -Name $apimServiceName 

Write-Host $apimService


$publicip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupNameApim -name $appGatewayPublicIpName

$appGatewayPuplicIp = $publicip.IpAddress
Write-Host "app gateway public ip $appGatewayPuplicIp"

$apimPrivateIp = $apimService.PrivateIPAddresses[0]
$apimPublicIp = $apimService.PublicIPAddresses[0]
Write-Host "apim public ip addresses $apimPublicIp"
Write-Host "apim private ip addresses $apimPrivateIp"

echo "$appGatewayPuplicIp $gatewayHostname" > C:\Windows\System32\drivers\etc\hosts.external
echo "$appGatewayPuplicIp $portalHostname" >> C:\Windows\System32\drivers\etc\hosts.external
echo "$appGatewayPuplicIp $managementHostname" >> C:\Windows\System32\drivers\etc\hosts.external

Write-Host "external host file"
Get-Content C:\Windows\System32\drivers\etc\hosts.external


echo "$apimPrivateIp $gatewayHostname" > C:\Windows\System32\drivers\etc\hosts.internal
echo "$apimPrivateIp $portalHostname" >> C:\Windows\System32\drivers\etc\hosts.internal
echo "$apimPrivateIp $managementHostname" >> C:\Windows\System32\drivers\etc\hosts.internal

Write-Host "internal host file"
Get-Content C:\Windows\System32\drivers\etc\hosts.internal

Write-Host "grabbing internal host file"
Copy-Item -Force C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts.default
Copy-Item -Force C:\Windows\System32\drivers\etc\hosts.internal C:\Windows\System32\drivers\etc\hosts
Get-Content C:\Windows\System32\drivers\etc\hosts

ping $gatewayHostname

#do not check for certification revocation status
echo "testing https://$gatewayHostname"
curl "https://$gatewayHostname" --ssl-no-revoke

echo "testing https://$gatewayHostname/echo/resource?param1=sample"
curl "https://$gatewayHostname/echo/resource?param1=sample" --ssl-no-revoke

echo "do a post"
curl -d '{"vehicleType":"train","maxSpeed":125,"avgSpeed":90,"speedUnit":"mph"}' "https://$gatewayHostname/echo/resource" --ssl-no-revoke

echo "testing https://$portalHostname"
curl "https://$portalHostname" --ssl-no-revoke
