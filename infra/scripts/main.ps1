# You can write your azure powershell scripts inline here. 
# You can also pass predefined and custom variables to this script using arguments
Param( 

    [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "location")]        
    [String]$location,
    
    [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "ResourceGroupNameApim")]
    [String]$ResourceGroupNameApim,

    [PARAMETER(Mandatory = $True, Position = 2, HelpMessage = "zoneName")]
    [String]$zoneName,

    [PARAMETER(Mandatory = $True, Position = 3, HelpMessage = "appGatewayName")]        
    [String]$appGatewayName,
    
    [PARAMETER(Mandatory = $True, Position = 4, HelpMessage = "GitVersion.SemVer")]
    [String]$GitVersionSemVer,

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

Write-Host create rg

Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

$azurePassword = ConvertTo-SecureString "$azureClientSecret" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureApplicationId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

New-AzResourceGroup -Name $ResourceGroupNameApim -Location $location -Tag @{"infraVersionFromPipeline" = "v $GitVersionSemVer" } -Force

Write-Host Create a virtual network and a subnet for the application gateway
$appGwRule1 = New-AzNetworkSecurityRuleConfig -Name appgw-in -Description "AppGw inbound" `
    -Access Allow -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix `
    GatewayManager -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 65200-65535
$appGwRule2 = New-AzNetworkSecurityRuleConfig -Name appgw-in-internet -Description "AppGw inbound Internet" `
    -Access Allow -Protocol "TCP" -Direction Inbound -Priority 110 -SourceAddressPrefix `
    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$appGwNsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupNameApim -Location $location -Name `
    "NSG-APPGW" -SecurityRules $appGwRule1, $appGwRule2 -Force

$apimRule1 = New-AzNetworkSecurityRuleConfig -Name apim-in -Description "APIM inbound" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix `
    ApiManagement -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 3443 
$apimNsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupNameApim -Location $location -Name `
    "NSG-APIM" -SecurityRules $apimRule1 -Force

Write-Host new onward
$appGatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name "appGatewaySubnet" -NetworkSecurityGroup $appGwNsg -AddressPrefix "10.0.0.0/24"
$apimSubnet = New-AzVirtualNetworkSubnetConfig -Name "apimSubnet" -NetworkSecurityGroup $apimNsg -AddressPrefix "10.0.1.0/24"
$vnet = New-AzVirtualNetwork -Name "appgwvnet" -ResourceGroupName $ResourceGroupNameApim `
    -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $appGatewaySubnet, $apimSubnet -Force
$appGatewaySubnetData = $vnet.Subnets[0]
$apimSubnetData = $vnet.Subnets[1]

Write-Host Create an API Management instance inside a virtual network

$apimVirtualNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $apimSubnetData.Id          
$apimService = New-AzApiManagement -ResourceGroupName $ResourceGroupNameApim -Location $location -Name $apimServiceName `
    -Organization "$apimOrganization" -AdminEmail $apimAdminEmail -VirtualNetwork $apimVirtualNetwork `
    -VpnType "Internal" -Sku "Developer"

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

$apimService.ProxyCustomHostnameConfiguration = $gatewayHostnameConfig
$apimService.PortalCustomHostnameConfiguration = $portalHostnameConfig
$apimService.ManagementCustomHostnameConfiguration = $managementHostnameConfig

Set-AzApiManagement -InputObject $apimService

Write-Host Configure a private zone for DNS resolution in the virtual network
$existingZonesJson = az network private-dns zone list -g $ResourceGroupNameApim
$existingZones = $existingZonesJson | ConvertFrom-Json
if ( $existingZones.count -eq 0 ) {
    $myZone = New-AzPrivateDnsZone -Name "$zoneName" -ResourceGroupName $ResourceGroupNameApim 
    $link = New-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName `
        -ResourceGroupName $ResourceGroupNameApim -Name "mylink" `
        -VirtualNetworkId $vnet.id

    Write-Host Create A records for the custom domain host names that map to the private IP address of API Management.

    $apimIP = $apimService.PrivateIPAddresses[0]

    New-AzPrivateDnsRecordSet -Name api -RecordType A -ZoneName $zoneName `
        -ResourceGroupName $ResourceGroupNameApim -Ttl 3600 `
        -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $apimIP)
    New-AzPrivateDnsRecordSet -Name portal -RecordType A -ZoneName $zoneName `
        -ResourceGroupName $ResourceGroupNameApim -Ttl 3600 `
        -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $apimIP)
    New-AzPrivateDnsRecordSet -Name management -RecordType A -ZoneName $zoneName `
        -ResourceGroupName $ResourceGroupNameApim -Ttl 3600 `
        -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $apimIP)
}
else {
    Write-Host skipping creation of private zones
}          

Write-Host Create a public IP address for the front-end configuration
#Create a Standard public IP resource publicIP01 in the resource group.

$publicip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupNameApim `
    -name "publicIP01" -location $location -AllocationMethod Static -Sku Standard -Force
#An IP address is assigned to the application gateway when the service starts.

Write-Host Create application gateway configuration

$gipconfig = New-AzApplicationGatewayIPConfiguration -Name "gatewayIP01" -Subnet $appGatewaySubnetData
$fp01 = New-AzApplicationGatewayFrontendPort -Name "port01"  -Port 443
$fipconfig01 = New-AzApplicationGatewayFrontendIPConfig -Name "frontend1" -PublicIPAddress $publicip

$certGateway = New-AzApplicationGatewaySslCertificate -Name "gatewaycert" `
    -CertificateFile $gatewayCertPfxPath -Password $certGatewayPwd
$certPortal = New-AzApplicationGatewaySslCertificate -Name "portalcert" `
    -CertificateFile $portalCertPfxPath -Password $certPortalPwd
$certManagement = New-AzApplicationGatewaySslCertificate -Name "managementcert" `
    -CertificateFile $managementCertPfxPath -Password $certManagementPwd

$gatewayListener = New-AzApplicationGatewayHttpListener -Name "gatewaylistener" `
    -Protocol "Https" -FrontendIPConfiguration $fipconfig01 -FrontendPort $fp01 `
    -SslCertificate $certGateway -HostName $gatewayHostname -RequireServerNameIndication true
$portalListener = New-AzApplicationGatewayHttpListener -Name "portallistener" `
    -Protocol "Https" -FrontendIPConfiguration $fipconfig01 -FrontendPort $fp01 `
    -SslCertificate $certPortal -HostName $portalHostname -RequireServerNameIndication true
$managementListener = New-AzApplicationGatewayHttpListener -Name "managementlistener" `
    -Protocol "Https" -FrontendIPConfiguration $fipconfig01 -FrontendPort $fp01 `
    -SslCertificate $certManagement -HostName $managementHostname -RequireServerNameIndication true

$apimGatewayProbe = New-AzApplicationGatewayProbeConfig -Name "apimgatewayprobe" `
    -Protocol "Https" -HostName $gatewayHostname -Path "/status-0123456789abcdef" `
    -Interval 30 -Timeout 120 -UnhealthyThreshold 8
$apimPortalProbe = New-AzApplicationGatewayProbeConfig -Name "apimportalprobe" `
    -Protocol "Https" -HostName $portalHostname -Path "/signin" `
    -Interval 60 -Timeout 300 -UnhealthyThreshold 8
$apimManagementProbe = New-AzApplicationGatewayProbeConfig -Name "apimmanagementprobe" `
    -Protocol "Https" -HostName $managementHostname -Path "/ServiceStatus" `
    -Interval 60 -Timeout 300 -UnhealthyThreshold 8

$trustedRootCert = New-AzApplicationGatewayTrustedRootCertificate -Name "whitelistcert1" -CertificateFile $trustedRootCertCerPath

$apimPoolGatewaySetting = New-AzApplicationGatewayBackendHttpSettings -Name "apimPoolGatewaySetting" `
    -Port 443 -Protocol "Https" -CookieBasedAffinity "Disabled" -Probe $apimGatewayProbe `
    -TrustedRootCertificate $trustedRootCert -PickHostNameFromBackendAddress -RequestTimeout 180
$apimPoolPortalSetting = New-AzApplicationGatewayBackendHttpSettings -Name "apimPoolPortalSetting" `
    -Port 443 -Protocol "Https" -CookieBasedAffinity "Disabled" -Probe $apimPortalProbe `
    -TrustedRootCertificate $trustedRootCert -PickHostNameFromBackendAddress -RequestTimeout 180
$apimPoolManagementSetting = New-AzApplicationGatewayBackendHttpSettings -Name "apimPoolManagementSetting" `
    -Port 443 -Protocol "Https" -CookieBasedAffinity "Disabled" -Probe $apimManagementProbe `
    -TrustedRootCertificate $trustedRootCert -PickHostNameFromBackendAddress -RequestTimeout 180

$apimGatewayBackendPool = New-AzApplicationGatewayBackendAddressPool -Name "gatewaybackend" `
    -BackendFqdns $gatewayHostname
$apimPortalBackendPool = New-AzApplicationGatewayBackendAddressPool -Name "portalbackend" `
    -BackendFqdns $portalHostname
$apimManagementBackendPool = New-AzApplicationGatewayBackendAddressPool -Name "managementbackend" `
    -BackendFqdns $managementHostname

$gatewayRule = New-AzApplicationGatewayRequestRoutingRule -Name "gatewayrule" `
    -RuleType Basic -HttpListener $gatewayListener -BackendAddressPool $apimGatewayBackendPool `
    -BackendHttpSettings $apimPoolGatewaySetting -Priority 10009
$portalRule = New-AzApplicationGatewayRequestRoutingRule -Name "portalrule" `
    -RuleType Basic -HttpListener $portalListener -BackendAddressPool $apimPortalBackendPool `
    -BackendHttpSettings $apimPoolPortalSetting -Priority 10012
$managementRule = New-AzApplicationGatewayRequestRoutingRule -Name "managementrule" `
    -RuleType Basic -HttpListener $managementListener -BackendAddressPool $apimManagementBackendPool `
    -BackendHttpSettings $apimPoolManagementSetting -Priority 10015

$sku = New-AzApplicationGatewaySku -Name "WAF_v2" -Tier "WAF_v2" -Capacity 2

$config = New-AzApplicationGatewayWebApplicationFirewallConfiguration -Enabled $true -FirewallMode "Prevention"

$policy = New-AzApplicationGatewaySslPolicy -PolicyType Predefined -PolicyName AppGwSslPolicy20220101

Write-Host Create an application gateway

$appgwName = "apim-app-gw"
$appgw = New-AzApplicationGateway -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim -Location $location `
    -BackendAddressPools $apimGatewayBackendPool, $apimPortalBackendPool, $apimManagementBackendPool `
    -BackendHttpSettingsCollection $apimPoolGatewaySetting, $apimPoolPortalSetting, $apimPoolManagementSetting `
    -FrontendIpConfigurations $fipconfig01 -GatewayIpConfigurations $gipconfig -FrontendPorts $fp01 `
    -HttpListeners $gatewayListener, $portalListener, $managementListener `
    -RequestRoutingRules $gatewayRule, $portalRule, $managementRule `
    -Sku $sku -WebApplicationFirewallConfig $config -SslCertificates $certGateway, $certPortal, $certManagement `
    -TrustedRootCertificate $trustedRootCert -Probes $apimGatewayProbe, $apimPortalProbe, $apimManagementProbe `
    -SslPolicy $policy

Write-Host After the application gateway deploys, confirm the health status of the API Management back ends in the portal or by running the following command

Get-AzApplicationGatewayBackendHealth -Name $appGatewayName -ResourceGroupName $ResourceGroupNameApim