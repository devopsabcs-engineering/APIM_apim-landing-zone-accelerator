# Windows PowerShell and PowerShell Core are supported.
# - Microsoft.Graph PowerShell module needs to be installed.
# - Azure CLI needs to be installed and authenticated for the owning tenant.
#
# Usage:
# - dot-source in a PS script: . ./Create-AzureAAD.ps1

function Initialize-AadTenant {
  [CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
  param (
    [Parameter(Mandatory = $true, HelpMessage = "AAD tenant name, without the '.onmicrosoft.com'.")]
    [string] $TenantName,
     
    [Parameter(Mandatory = $true, HelpMessage = "Thumbprint for certificate to use with ms graph api.")]
    [string] $aadAdoClientCertThumbprint,
    [Parameter(Mandatory = $true, HelpMessage = "aadAdoClientId")]
    [string] $aadAdoClientId,
    # [Parameter(Mandatory = $true, HelpMessage = "clientId")]
    # [string] $clientId,
    # [Parameter(Mandatory = $true, HelpMessage = "clientSecret")]
    # [string] $clientSecret
    [Parameter(Mandatory = $true, HelpMessage = "userId")]
    [string] $userId,
    [Parameter(Mandatory = $true, HelpMessage = "userPassword")]
    [securestring] $userPassword,

    [Parameter(HelpMessage = "Full ADO organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $AdoOrganization,

    [Parameter(HelpMessage = "ADO project name. Typically follows the organization name in the URL.")]
    [string] $AdoProjectName,

    [Parameter(HelpMessage = "Personal Access Token which grants access to variable groups and secret files.")]
    [string] $AdoPAT,

    [Parameter(HelpMessage = "Variable group DEV in which service principal information will be stored. Will be created if it doesn't exist.")]
    [string] $AdoVariableGroupNameDev,
    [Parameter(HelpMessage = "Variable group PRD in which service principal information will be stored. Will be created if it doesn't exist.")]
    [string] $AdoVariableGroupNamePrd,
    [string] $aadExtensionsAppClientId,
    [string] $aadExtensionsAppClientSecret,
    [string] $aadTenantId
  )

  Write-Host "Initializing AAD tenant $TenantName."
  Write-Host "org: $AdoOrganization and project: $AdoProjectName"

  if (Get-Module -ListAvailable -Name Microsoft.Graph) {
    Write-Host "Module Microsoft.Graph exists."
  }
  else {
    throw "Module Microsoft.Graph is not installed yet. Please install it first! Run 'Install-Module Microsoft.Graph'."
  }  

  
  Write-Host "*** Skipping creation of AAD tenant..."
  Write-Host "get all certs"
  Get-ChildItem Cert:\LocalMachine\My\
          
  # Authenticate
  $certInstore = Get-ChildItem "Cert:\LocalMachine\My\$aadAdoClientCertThumbprint"
  Write-Host certificate $certInstore
  #az login --service-principal -u ${app_id} -p ${password} --tenant ${tenant_id}
  Write-Host "logging in with user $userId"
  #ps 7
  #$plainTextUserPassword = ConvertFrom-SecureString -AsPlainText $userPassword
  #ps 5.1
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword)
  $plainTextUserPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

  az login -u "$userId" -p "$plainTextUserPassword" --scope "https://management.core.windows.net//.default" --tenant "$TenantName.onmicrosoft.com" --allow-no-subscriptions
  Write-Host "DONE logging in with user $userId"
  Connect-MgGraph -ClientId $aadAdoClientId -TenantId "$TenantName.onmicrosoft.com" -Certificate $certInstore
  Get-MgContext
  

  # Create Application for the Backend DEV
  $beAppDev = New-BackendApp `
    -TenantName $TenantName `
    -environmentName "dev"
  
  $BackendHelloScopeIdDev = $beAppDev.HelloScopeId
  $BackendAppAppIdDev = $beAppDev.ClientID
  $BackendServicePrincipalIdDev = $beAppDev.ServicePrincipalId

  # Create Application for the Backend PROD
  $beAppPrd = New-BackendApp `
    -TenantName $TenantName `
    -environmentName "prd"
  
  #az ad app show --id  $beApp.ClientID

  $BackendHelloScopeIdPrd = $beAppPrd.HelloScopeId
  $BackendAppAppIdPrd = $beAppPrd.ClientID
  $BackendServicePrincipalIdPrd = $beAppPrd.ServicePrincipalId
  
  # Create Application for the Frontend DEV
  $feAppDev = New-FrontendApp `
    -TenantName $TenantName `
    -BackendHelloScopeId $BackendHelloScopeIdDev `
    -BackendAppAppId $BackendAppAppIdDev `
    -BackendServicePrincipalId $BackendServicePrincipalIdDev `
    -environmentName "dev"

  # Create Application for the Frontend PROD  
  $feAppPrd = New-FrontendApp `
    -TenantName $TenantName `
    -BackendHelloScopeId $BackendHelloScopeIdPrd `
    -BackendAppAppId $BackendAppAppIdPrd `
    -BackendServicePrincipalId $BackendServicePrincipalIdPrd `
    -environmentName "prd"

  # Create Application for the Frontend API Management DEV
  $feApimAppDev = New-FrontendApimDevPortalApp `
    -TenantName $TenantName `
    -BackendHelloScopeId $BackendHelloScopeIdDev `
    -BackendAppAppId $BackendAppAppIdDev `
    -BackendServicePrincipalId $BackendServicePrincipalIdDev `
    -environmentName "dev"

  # Create Application for the Frontend API Management PROD
  $feApimAppPrd = New-FrontendApimDevPortalApp `
    -TenantName $TenantName `
    -BackendHelloScopeId $BackendHelloScopeIdPrd `
    -BackendAppAppId $BackendAppAppIdPrd `
    -BackendServicePrincipalId $BackendServicePrincipalIdPrd `
    -environmentName "prd"

  # # Create the Graph Client application for the Worker
  # $workerApp = New-WorkerApp

  # Create demo users
  . ./Create-Users.ps1 # dot-sourcing only now, to prevent interference with the previous steps

  Write-Host "Switching context as we now need access tokens for graph API beta..."

  Write-Host "AAD Tenant ID: $aadTenantId"

  . .\Connect-MgGraphWorkaround.ps1 # workaround for Connect-MgGraph bug use app registration
  $retValue = Get-AccessToken -ClientId $aadExtensionsAppClientId `
    -ClientSecret  "$aadExtensionsAppClientSecret" `
    -TenantId $aadTenantId 

  $accessToken = $retValue.AccessToken

  # Authenticate to the Microsoft Graph
  Connect-MgGraph -AccessToken $accessToken

  # Get Context
  Get-MgContext

  try {
    $createdUsers = Import-Users `
      -TenantName $TenantName `
      -managementAccessToken $accessToken
  }
  catch {
    Write-Host "Error when creating users, there's a chance they've already been created."
  }    

  # TODO: Integrate Create-ServicePrincipal.ps1
  . ./Create-ServicePrincipal.ps1

  # Update variable groups DEV
  #APIM_b2c_frontend_dev_vars
  $api_scopes = "https://$TenantName.onmicrosoft.com/$BackendAppAppIdDev/Hello"
  $msal_auth_authority = "https://login.microsoftonline.com/$TenantName.onmicrosoft.com"
  $msal_auth_clientid = $feAppDev.ClientID
  $msal_auth_known_authorities = "login.microsoftonline.com" #https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-client-application-configuration
  $beClientSecret = $beAppDev.ClientSecret
  $beClientId = $beAppDev.ClientID
  $apimFrontendClientId = $feApimAppDev.ClientID
  $apimFrontendClientSecret = $feApimAppDev.ClientSecret
  #$idpClientSecret = $idpAppDev.ClientSecret
  #$idpClientId = $idpAppDev.ClientID
  #$idpAppDisplayName = $idpAppDev.DisplayName
  $adoVarsDev = @{
    #idpClientSecret             = @{ value = $idpClientSecret; secret = "false" };
    #idpClientId                 = @{ value = $idpClientId; secret = "false" };
    #idpAppDisplayName           = @{ value = $idpAppDisplayName; secret = "false" };
    backendClientSecret         = @{ value = $beClientSecret; secret = "false" };
    backendClientId             = @{ value = $beClientId; secret = "false" };
    apimFrontendClientSecret    = @{ value = $apimFrontendClientSecret; secret = "false" };
    apimFrontendClientId        = @{ value = $apimFrontendClientId; secret = "false" };
    API_BACKEND                 = @{ value = "FIX ME dev"; secret = "false" };
    API_SCOPES                  = @{ value = $api_scopes; secret = "false" };
    MSAL_AUTH_AUTHORITY         = @{ value = $msal_auth_authority; secret = "false" };
    MSAL_AUTH_CLIENTID          = @{ value = $msal_auth_clientid; secret = "false" };
    MSAL_AUTH_KNOWN_AUTHORITIES = @{ value = $msal_auth_known_authorities; secret = "false" };
    MSAL_AUTH_REDIRECT_URI      = @{ value = "FIX ME dev"; secret = "false" }; #not secret, just for testing
    TITLE_SUFFIX                = @{ value = "DevelopmentEnv"; secret = "false" }
  }
  Write-Host "Updating variable group $AdoVariableGroupNameDev for org $AdoOrganization and project $AdoProjectName"
  $adoVarsDevJson = $adoVarsDev | ConvertTo-Json -Depth 10
  Set-Content -Path ./Output/variables/$AdoVariableGroupNameDev.json -Value $adoVarsDevJson
  Write-Host "CAREFUL: Variable group $AdoVariableGroupNameDev updated"
  Get-Content ./Output/variables/$AdoVariableGroupNameDev.json
  # Update-ADO `
  #   -PatToken $AdoPAT `
  #   -OrganizationUrl $AdoOrganization `
  #   -Project $AdoProjectName `
  #   -VariableGroupName $AdoVariableGroupNameDev `
  #   -Variables $adoVarsDev

  # Update variable groups PROD
  #APIM_b2c_frontend_prod_vars
  $api_scopes = "https://$TenantName.onmicrosoft.com/$BackendAppAppIdPrd/Hello"
  $msal_auth_authority = "https://login.microsoftonline.com/$TenantName.onmicrosoft.com"
  $msal_auth_clientid = $feAppPrd.ClientID
  $msal_auth_known_authorities = "login.microsoftonline.com" #https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-client-application-configuration
  $beClientSecret = $beAppPrd.ClientSecret
  $beClientId = $beAppPrd.ClientID
  $apimFrontendClientId = $feApimAppPrd.ClientID
  $apimFrontendClientSecret = $feApimAppPrd.ClientSecret
  #$idpClientSecret = $idpAppPrd.ClientSecret
  #$idpClientId = $idpAppPrd.ClientID
  #$idpAppDisplayName = $idpAppPrd.DisplayName
  $adoVarsPrd = @{
    #idpClientSecret             = @{ value = $idpClientSecret; secret = "false" };
    #idpClientId                 = @{ value = $idpClientId; secret = "false" };
    #idpAppDisplayName           = @{ value = $idpAppDisplayName; secret = "false" };
    backendClientSecret         = @{ value = $beClientSecret; secret = "false" };
    backendClientId             = @{ value = $beClientId; secret = "false" };
    apimFrontendClientSecret    = @{ value = $apimFrontendClientSecret; secret = "false" };
    apimFrontendClientId        = @{ value = $apimFrontendClientId; secret = "false" };
    API_BACKEND                 = @{ value = "FIX ME prd"; secret = "false" };
    API_SCOPES                  = @{ value = $api_scopes; secret = "false" };
    MSAL_AUTH_AUTHORITY         = @{ value = $msal_auth_authority; secret = "false" };
    MSAL_AUTH_CLIENTID          = @{ value = $msal_auth_clientid; secret = "false" };
    MSAL_AUTH_KNOWN_AUTHORITIES = @{ value = $msal_auth_known_authorities; secret = "false" };
    MSAL_AUTH_REDIRECT_URI      = @{ value = "FIX ME prd"; secret = "false" }; #not secret, just for testing
    TITLE_SUFFIX                = @{ value = "ProductionEnv"; secret = "false" }
  }
  Write-Host "Updating variable group $AdoVariableGroupNamePrd for org $AdoOrganization and project $AdoProjectName"
  $adoVarsPrdJson = $adoVarsPrd | ConvertTo-Json -Depth 10
  Set-Content -Path ./Output/variables/$AdoVariableGroupNamePrd.json -Value $adoVarsPrdJson
  Write-Host "CAREFUL: Variable group $AdoVariableGroupNamePrd updated"
  Get-Content ./Output/variables/$AdoVariableGroupNamePrd.json
  # Update-ADO `
  #   -PatToken $AdoPAT `
  #   -OrganizationUrl $AdoOrganization `
  #   -Project $AdoProjectName `
  #   -VariableGroupName $AdoVariableGroupNamePrd `
  #   -Variables $adoVarsPrd  

  return @{
    BackendAppClientIDDev        = $beAppDev.ClientID
    BackendClientSecretDev       = $beAppDev.ClientSecret
    BackendHelloScopeIdDev       = $beAppDev.HelloScopeId
    BackendServicePrincipalIdDev = $beAppDev.ServicePrincipalId
    FrontendAppClientIDDev       = $feAppDev.ClientID
    FrontendClientSecretDev      = $feAppDev.ClientSecret
    FrontendApimAppClientIDDev   = $feApimAppDev.ClientID
    FrontendApimClientSecretDev  = $feApimAppDev.ClientSecret
    BackendAppClientIDPrd        = $beAppPrd.ClientID
    BackendClientSecretPrd       = $beAppPrd.ClientSecret
    BackendHelloScopeIdPrd       = $beAppPrd.HelloScopeId
    BackendServicePrincipalIdPrd = $beAppPrd.ServicePrincipalId
    FrontendAppClientIDPrd       = $feAppPrd.ClientID
    FrontendClientSecretPrd      = $feAppPrd.ClientSecret
    FrontendApimAppClientIDPrd   = $feApimAppPrd.ClientID
    FrontendApimClientSecretPrd  = $feApimAppPrd.ClientSecret
    #UIAppClientID             = $uiApp.ClientID
    #WorkerClientID            = $workerApp.ClientID
    #WorkerClientSecret        = $workerApp.ClientSecret
    Users                        = $createdUsers
  }
}

#
# Create new Azure AD tenant in a specific subscription and resource group.
# Must be followed by Invoke-TenantInit to finalize the creation of default apps.
#
# Required: Azure CLI authenticated for the target subscription.
# Required: Resource provider: "Microsoft.AzureActiveDirectory". The function will attempt to register if not done so yet.
#   az provider register --namespace Microsoft.AzureActiveDirectory
#
# Azure PowerShell Alternative: Invoke-AzRestMethod


#
# Finalize initialization of newly created AAD tenant.
# This function needs to be called once the tenant is created and before any other steps, because it creates the aad-extensions-app.
#
# Required: Azure CLI authenticated with owner permissions for the tenant.
function Invoke-TenantInit {
  param (
    [string] $TenantName
  )

  $TenantId = "$($TenantName).onmicrosoft.com"
  Get-AzTenant
  $TenantId = (get-aztenant | Where-Object { $_.Domains -match "$TenantId" }).Id
  Write-Host "AAD Tenant ID: $TenantId"

  # Get access token for the AAD tenant with audience "management.core.windows.net".
  #$managementAccessToken = $(az account get-access-token --tenant "$TenantId" --query accessToken -o tsv)

  Write-Host "Creating the AAD extension app for tenant initialization..."

  . .\Create-AadExtensionsApp.ps1 
  
  $aadExtensionsApp = New-AadExtensionsApp -TenantId $TenantId

  Write-Host "Waiting for 30 seconds for AAD Extension app registration creation..."
  Start-Sleep -Seconds 30

  return @{
    ClientID     = $aadExtensionsApp.ClientID
    ClientSecret = $aadExtensionsApp.ClientSecret
    TenantId     = $aadExtensionsApp.TenantId
  }
}

#https://learn.microsoft.com/en-us/graph/api/directory-post-attributesets?view=graph-rest-beta&tabs=http
function Add-CustomAttributeSet {
  param (
    [string] $TenantName,
    [string] $managementAccessToken,
    [string] $AttributeSetName,
    [string] $Description,
    [string] $maxAttributesPerSet = 25
  )

  $TenantId = "$($TenantName).onmicrosoft.com"
  Get-AzTenant
  $TenantId = (get-aztenant | Where-Object { $_.Domains -match "$TenantId" }).Id
  Write-Host "AAD Tenant ID: $TenantId"

  # Get access token for the AAD tenant with audience "management.core.windows.net".
  #$managementAccessToken = $(az account get-access-token --tenant $TenantId --query accessToken -o tsv)

  $reqBody = @"
{
  "id": "$($AttributeSetName)",
  "description": "$($Description)",
  "maxAttributesPerSet":  $($maxAttributesPerSet)
}
"@ # no whitespace permitted before the closing sequence

  # Create the attribute using the same method as the Portal.
  Write-Host "Creating custom attribute set $($AttributeSetName)..."
  Invoke-WebRequest -Uri "https://graph.microsoft.com/beta/directory/attributeSets" `
    -Method "POST" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)";
    "Content-Type"  = "application/json"
  } `
    -Body $reqBody
}

#
# Create a custom user attribute in the tenant.
#
# Requires: Azure CLI authenticated with owner permissions for the tenant.
# Alternatively, the /beta/identity/userFlowAttributes Graph endpoint can be used.
function Add-CustomAttribute {
  param (
    [string] $TenantName,
    [string] $managementAccessToken,
    [string] $AttributeName,
    [string] $AttributeSetName,
    [string] $Description,
    [string] $DataType = "String"
  )

  $TenantId = "$($TenantName).onmicrosoft.com"
  Get-AzTenant
  $TenantId = (get-aztenant | Where-Object { $_.Domains -match "$TenantId" }).Id
  Write-Host "AAD Tenant ID: $TenantId"

  # Get access token for the AAD tenant with audience "management.core.windows.net".
  #$managementAccessToken = $(az account get-access-token --tenant $TenantId --query accessToken -o tsv)
  $reqBody = @"
{
    "attributeSet":"$($AttributeSetName)",
    "description":"$($Description)",
    "isCollection":false,
    "isSearchable":true,
    "name":"$($AttributeName)",
    "status":"Available",
    "type":"$($DataType)",
    "usePreDefinedValuesOnly": false
}
"@ # no whitespace permitted before the closing sequence

  # getting current attributes 
  Write-Host "Getting current custom attributes..."
  Invoke-WebRequest -Uri "https://graph.microsoft.com/beta/directory/customSecurityAttributeDefinitions?`$expand=allowedValues" `
    -Method "GET" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)";
    "Content-Type"  = "application/json"
  }

  # Create the attribute using the same method as the Portal.
  Write-Host "Creating custom attribute $($AttributeName)..."
  Invoke-WebRequest -Uri "https://graph.microsoft.com/beta/directory/customSecurityAttributeDefinitions" `
    -Method "POST" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)";
    "Content-Type"  = "application/json"
  } `
    -Body $reqBody
}

#
# Creates a AAD application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-UIApp {
  param (
    [string] $TenantName
  )

  # Create the Apis.Access permission scope
  $apisAccessScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
  $apisAccessScope.AdminConsentDescription = "Allows the app to access to api data on behalf of a user."
  $apisAccessScope.AdminConsentDisplayName = "Access apis"
  $apisAccessScope.Id = New-Guid
  $apisAccessScope.IsEnabled = $true
  $apisAccessScope.Type = "Admin"
  $apisAccessScope.Value = "Apis.Access"

  # Create the UI application
  $uiApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
  $uiApp.DisplayName = "UI application"
  $uiApp.SignInAudience = "AzureADandPersonalMicrosoftAccount"
  $uiApp.Spa.RedirectUris = "http://localhost:8080"
  $uiApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $true
  $uiApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $true
  $uiApp.IsFallbackPublicClient = $true
  $uiApp.Api.Oauth2PermissionScopes = $apisAccessScope

  Write-Host "Creating UI application..."
  $uiApp = New-MgApplication -BodyParameter $uiApp
  Write-Host "Successfully created UI app with applicationId $($uiApp.AppId)"

  # Adding Apis.Access API permission
  $apisRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $apisRRA.ResourceAccess = @{ Id = $apisAccessScope.Id; Type = "Scope" }
  $apisRRA.ResourceAppId = $uiApp.AppId # ID of the resource that application requires access to - it's the same in our case

  # Well-known ID for offline_access = 7427e0e9-2fba-42fe-b0c0-848c9e6a8182
  $offlineAccessScope = @{ Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"; Type = "Scope" }

  # Well-known ID for openid = 37f7f235-527c-4136-accd-4a02d197296e
  $openidScope = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope" }

  # offline_access and openid scopes are tied to the same app
  $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRRA.ResourceAccess = @($offlineAccessScope, $openidScope)
  $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants

  $resourceAccessList = @(
    $apisRRA
    $graphRRA
  )

  # Update UI app with the API permission and identifier URI.
  # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
  Write-Host "Assigning Apis.Access and openid permissions for the UI application..."
  Update-MgApplication `
    -ApplicationId $uiApp.Id `
    -RequiredResourceAccess $resourceAccessList `
    -IdentifierUris "https://$($TenantName).onmicrosoft.com/$($uiApp.AppId)"

  # Service principal for the application is not created automatically.
  # It's needed for admin consent etc.
  $servicePrincipal = New-MgServicePrincipal -AppId $uiApp.AppId

  # Admin Consent - for the UI app this is OAuth2 Permission Grant
  Write-Host "Updating admin consent for the UI app..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope $apisAccessScope.Value `
    -ResourceId $servicePrincipal.Id | Out-Null

  Write-Host "*** Azure AD Application '$($uiApp.DisplayName)' created."
  Write-Host "*** Client ID: $($uiApp.AppId)"

  return @{
    ClientID = $uiApp.AppId
  }
}

#
# Creates a AAD application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-BackendApp {
  param (
    [string] $TenantName,
    [string] $environmentName
  )

  # Prepare Microsoft Graph access for user details
  # User.Read.All scope is pre-defined in the Microsoft.Graph global application - App ID is hardcoded here and doesn't change across tenants. The service principal ID changes per tenant though.
  # Static appId for Microsoft Graph across Azure AD - https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/verify-first-party-apps-sign-in#application-ids-for-commonly-used-microsoft-applications
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

  # All scopes and IDs can be found with this Graph query: https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '00000003-0000-0000-c000-000000000000'&$select=appRoles, oauth2PermissionScopes
  $userReadAllScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess
  $userReadAllScope.Id = "df021288-bdef-4463-88db-98f22de89214" # Well-known ID, the same across all tenants
  $userReadAllScope.Type = "Role" # Application permissions

  $graphRequiredResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRequiredResourceAccess.ResourceAccess = $userReadAllScope
  $graphRequiredResourceAccess.ResourceAppId = $graphServicePrincipal.AppId
 
  # Create the Hello permission scope
  $apisAccessScopeHello = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
  $apisAccessScopeHello.AdminConsentDescription = "Hello consent description"
  $apisAccessScopeHello.AdminConsentDisplayName = "Hello"
  $apisAccessScopeHello.Id = New-Guid
  $apisAccessScopeHello.IsEnabled = $true
  $apisAccessScopeHello.Type = "Admin"
  $apisAccessScopeHello.Value = "Hello"  

  # Create the Backend application
  $beApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
  $beApp.DisplayName = "Backend application $environmentName"
  $beApp.SignInAudience = "AzureADandPersonalMicrosoftAccount"
  $beApp.Web.RedirectUris = "https://jwt.ms"
  $beApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
  $beApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $false
  #$beApp.IsFallbackPublicClient = $true
  $beApp.RequiredResourceAccess = $graphRequiredResourceAccess
  $beApp.Api.Oauth2PermissionScopes = $apisAccessScopeHello #could be an array of scopes as well

  Write-Host "Creating Backend application for $environmentName environment..."
  $beApp = New-MgApplication -BodyParameter $beApp
  Write-Host "Successfully created Backend app $environmentName with applicationId $($beApp.AppId)"  

  # # Adding Hello API permission
  # $apisRRAHello = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  # $apisRRAHello.ResourceAccess = @{ Id = $apisAccessScopeHello.Id; Type = "Scope" }
  # $apisRRAHello.ResourceAppId = $beApp.AppId # ID of the resource that application requires access to - it's the same in our case

  # Well-known ID for User.Read = e1fe6dd8-ba31-4d61-89e7-88639da4683d
  $userReadScope = @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope" }

  # offline_access and openid scopes are tied to the same app
  $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRRA.ResourceAccess = @($userReadScope)
  $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants

  $resourceAccessList = @(    
    #$apisRRAHello
    $graphRRA
  )

  # Update Backend app with the API permission and identifier URI.
  # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
  Write-Host "Assigning Hello permissions for the Backend application $environmentName ..."
  Update-MgApplication `
    -ApplicationId $beApp.Id `
    -RequiredResourceAccess $resourceAccessList `
    -IdentifierUris "https://$($TenantName).onmicrosoft.com/$($beApp.AppId)"

  # Service principal for the application is not created automatically.
  # It's needed for admin consent etc.
  $servicePrincipal = New-MgServicePrincipal -AppId $beApp.AppId

  # Create secret for the app. This has to be done after the app is created.
  $secret = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential
  $secret.KeyId = New-Guid
  $secret.DisplayName = "Backend client secret for $environmentName environment"

  Write-Host "Creating secret for the Backend application $environmentName ..."
  $secret = Add-MgApplicationPassword -ApplicationId $beApp.Id -PasswordCredential $secret

  # # Admin Consent - for the Backend app this is OAuth2 Permission Grant
  # Write-Host "Updating admin consent for the Backend app..."
  # New-MgOauth2PermissionGrant `
  #   -ConsentType AllPrincipals `
  #   -ClientId $servicePrincipal.Id `
  #   -Scope $apisAccessScopeHello.Value `
  #   -ResourceId $servicePrincipal.Id | Out-Null
    
  #-Scope $apisAccessScope.Value $apisAccessScope2.Value `

  Write-Host "*** Azure AD Application '$($beApp.DisplayName)' created."
  Write-Host "*** Client ID: $($beApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID           = $beApp.AppId
    ClientSecret       = $secret.SecretText
    HelloScopeId       = $apisAccessScopeHello.Id
    ServicePrincipalId = $servicePrincipal.Id
  }
}

#
# Creates a AAD application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-FrontendApp {
  param (
    [string] $TenantName,
    [string] $BackendHelloScopeId,
    [string] $BackendAppAppId,
    [string] $HelloScopeValue = 'Hello',
    [string] $BackendServicePrincipalId,
    [string] $environmentName
  )

  # # Create the Apis.Access permission scope
  # $apisAccessScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
  # $apisAccessScope.AdminConsentDescription = "Allows the app to access to api data on behalf of a user."
  # $apisAccessScope.AdminConsentDisplayName = "Access apis"
  # $apisAccessScope.Id = New-Guid
  # $apisAccessScope.IsEnabled = $true
  # $apisAccessScope.Type = "Admin"
  # $apisAccessScope.Value = "Apis.Access"

  # # Create the Apis.Access permission scope
  # $apisAccessScope2 = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
  # $apisAccessScope2.AdminConsentDescription = "Hello consent description."
  # $apisAccessScope2.AdminConsentDisplayName = "Hello"
  # $apisAccessScope2.Id = New-Guid
  # $apisAccessScope2.IsEnabled = $true
  # $apisAccessScope2.Type = "Admin"
  # $apisAccessScope2.Value = "Hello"  

  # Create the Frontend application
  $feApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
  $feApp.DisplayName = "Frontend application $environmentName"
  $feApp.SignInAudience = "AzureADandPersonalMicrosoftAccount"
  $feApp.Spa.RedirectUris = "https://jwt.ms" #eventually will be url of spa app e.g. static website https://storqnzxwgg2niqda.z9.web.core.windows.net
  $feApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
  $feApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $false
  #$feApp.IsFallbackPublicClient = $true
  #$feApp.Api.Oauth2PermissionScopes = @($apisAccessScope, $apisAccessScope2)

  Write-Host "Creating Frontend application $environmentName..."
  $feApp = New-MgApplication -BodyParameter $feApp
  Write-Host "Successfully created Frontend app $environmentName with applicationId $($feApp.AppId)"

  # # Adding Apis.Access API permission
  # $apisRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  # $apisRRA.ResourceAccess = @{ Id = $apisAccessScope.Id; Type = "Scope" }
  # $apisRRA.ResourceAppId = $feApp.AppId # ID of the resource that application requires access to - it's the same in our case

  # Adding Hello API permission
  $apisRRAHello = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $apisRRAHello.ResourceAccess = @{ Id = $BackendHelloScopeId; Type = "Scope" }
  $apisRRAHello.ResourceAppId = $BackendAppAppId # ID of the resource that application requires access to - it's the same in our case

  # Well-known ID for offline_access = 7427e0e9-2fba-42fe-b0c0-848c9e6a8182
  $offlineAccessScope = @{ Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"; Type = "Scope" }

  # Well-known ID for openid = 37f7f235-527c-4136-accd-4a02d197296e
  $openidScope = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope" }

  # offline_access and openid scopes are tied to the same app
  $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRRA.ResourceAccess = @($offlineAccessScope, $openidScope)
  $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants

  $resourceAccessList = @(    
    $apisRRAHello
    $graphRRA
  )

  # Update Frontend app with the API permission and identifier URI.
  # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
  Write-Host "Assigning Apis.Access and openid permissions for the Frontend application $environmentName..."
  Update-MgApplication `
    -ApplicationId $feApp.Id `
    -RequiredResourceAccess $resourceAccessList

  # Service principal for the application is not created automatically.
  # It's needed for admin consent etc.
  $servicePrincipal = New-MgServicePrincipal -AppId $feApp.AppId

  # Create secret for the app. This has to be done after the app is created.
  $secret = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential
  $secret.KeyId = New-Guid
  $secret.DisplayName = "Frontend client secret $environmentName"

  Write-Host "Creating secret for the Frontend application $environmentName..."
  $secret = Add-MgApplicationPassword -ApplicationId $feApp.Id -PasswordCredential $secret

  # Admin Consent - for the Frontend app this is OAuth2 Permission Grant
  Write-Host "Updating admin consent for the Frontend app $environmentName (hello backend)..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope $HelloScopeValue `
    -ResourceId $BackendServicePrincipalId | Out-Null

  # also consent for graph
  # need to connect to newly created aad tenant to grab service principal id aka object id for 'Microsoft Graph'
  #az login --scope https://management.core.windows.net//.default --tenant "$TenantName.onmicrosoft.com" --allow-no-subscriptions
  #$GraphAggregatorServiceServicePrincipalId = az ad sp list --filter "displayname eq 'Microsoft Graph'" --query '[0].id'
  #$GraphAggregatorServiceServicePrincipalId = "ea585e79-8454-429b-8343-0739a4ddc8d3"
  $GraphAggregatorServiceServicePrincipalId = (Get-MgServicePrincipal | Where-Object { $_.DisplayName -match "Microsoft Graph" } | Where-Object { $_.AppId -match "00000003-0000-0000-c000-000000000000" }).Id
  Write-Host "Graph Aggregator Service Service Principal ID: $GraphAggregatorServiceServicePrincipalId"  
  Write-Host "Updating admin consent for the Frontend app $environmentName (graph perms)..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope "offline_access openid" `
    -ResourceId $GraphAggregatorServiceServicePrincipalId | Out-Null
    
  #-Scope $apisAccessScope.Value $apisAccessScope2.Value `

  Write-Host "*** Azure AD Application '$($feApp.DisplayName)' created."
  Write-Host "*** Client ID: $($feApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID     = $feApp.AppId
    ClientSecret = $secret.SecretText
  }
}

#
# Creates a AAD application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-FrontendApimDevPortalApp {
  param (
    [string] $TenantName,
    [string] $BackendHelloScopeId,
    [string] $BackendAppAppId,
    [string] $HelloScopeValue = 'Hello',
    [string] $BackendServicePrincipalId,
    [string] $environmentName
  )

  # Create the Frontend APIM application
  $feApimApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
  $feApimApp.DisplayName = "Frontend App for APIM Dev Portal $environmentName"
  $feApimApp.SignInAudience = "AzureADandPersonalMicrosoftAccount"
  $feApimApp.Web.RedirectUris = "https://jwt.ms" #eventually will be url provided by APIM e.g. https://apim-fifgmevnwrnwu.developer.azure-api.net/signin-oauth/code/callback/prodoauthserverb2c
  $feApimApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
  $feApimApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $false
  #$feApp.IsFallbackPublicClient = $true
  #$feApp.Api.Oauth2PermissionScopes = @($apisAccessScope, $apisAccessScope2)

  Write-Host "Creating Frontend APIM application $environmentName..."
  $feApimApp = New-MgApplication -BodyParameter $feApimApp
  Write-Host "Successfully created Frontend APIM app $environmentName with applicationId $($feApimApp.AppId)"

  # Adding Hello API permission
  $apisRRAHello = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $apisRRAHello.ResourceAccess = @{ Id = $BackendHelloScopeId; Type = "Scope" }
  $apisRRAHello.ResourceAppId = $BackendAppAppId # ID of the resource that application requires access to - it's the same in our case

  # Well-known ID for offline_access = 7427e0e9-2fba-42fe-b0c0-848c9e6a8182
  $offlineAccessScope = @{ Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"; Type = "Scope" }

  # Well-known ID for openid = 37f7f235-527c-4136-accd-4a02d197296e
  $openidScope = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope" }

  # offline_access and openid scopes are tied to the same app
  $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRRA.ResourceAccess = @($offlineAccessScope, $openidScope)
  $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants

  $resourceAccessList = @(    
    $apisRRAHello
    $graphRRA
  )

  # Update Frontend app with the API permission and identifier URI.
  # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
  Write-Host "Assigning Apis.Access and openid permissions for the Frontend APIM application $environmentName..."
  Update-MgApplication `
    -ApplicationId $feApimApp.Id `
    -RequiredResourceAccess $resourceAccessList

  # Service principal for the application is not created automatically.
  # It's needed for admin consent etc.
  $servicePrincipal = New-MgServicePrincipal -AppId $feApimApp.AppId

  # Create secret for the app. This has to be done after the app is created.
  $secret = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential
  $secret.KeyId = New-Guid
  $secret.DisplayName = "Frontend APIM client secret $environmentName"

  Write-Host "Creating secret for the Frontend APIM application $environmentName..."
  $secret = Add-MgApplicationPassword -ApplicationId $feApimApp.Id -PasswordCredential $secret

  # Admin Consent - for the Frontend app this is OAuth2 Permission Grant
  Write-Host "Updating admin consent for the Frontend APIM app $environmentName (hello backend)..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope $HelloScopeValue `
    -ResourceId $BackendServicePrincipalId | Out-Null

  # also consent for graph
  # need to connect to newly created aad tenant to grab service principal id aka object id for 'Microsoft Graph'
  #az login --scope https://management.core.windows.net//.default --tenant "$TenantName.onmicrosoft.com" --allow-no-subscriptions
  #$GraphAggregatorServiceServicePrincipalId = az ad sp list --filter "displayname eq 'Microsoft Graph'" --query '[0].id'
  #$GraphAggregatorServiceServicePrincipalId = "ea585e79-8454-429b-8343-0739a4ddc8d3"
  $GraphAggregatorServiceServicePrincipalId = (Get-MgServicePrincipal | Where-Object { $_.DisplayName -match "Microsoft Graph" } | Where-Object { $_.AppId -match "00000003-0000-0000-c000-000000000000" }).Id
  Write-Host "Graph Aggregator Service Service Principal ID: $GraphAggregatorServiceServicePrincipalId" 
  Write-Host "Updating admin consent for the Frontend APIM app $environmentName (graph perms)..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope "offline_access openid" `
    -ResourceId $GraphAggregatorServiceServicePrincipalId | Out-Null
    
  #-Scope $apisAccessScope.Value $apisAccessScope2.Value `

  Write-Host "*** Azure AD AAD Application '$($feApimApp.DisplayName)' created."
  Write-Host "*** Client ID: $($feApimApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID     = $feApimApp.AppId
    ClientSecret = $secret.SecretText
  }
}

#
# Creates an AAD application to be used by a headless worker to access the Graph API to resolve user names.
#
function New-WorkerApp {
  # Prepare Microsoft Graph access for user details
  # User.Read.All scope is pre-defined in the Microsoft.Graph global application - App ID is hardcoded here and doesn't change across tenants. The service principal ID changes per tenant though.
  # Static appId for Microsoft Graph across Azure AD - https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/verify-first-party-apps-sign-in#application-ids-for-commonly-used-microsoft-applications
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

  # All scopes and IDs can be found with this Graph query: https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '00000003-0000-0000-c000-000000000000'&$select=appRoles, oauth2PermissionScopes
  $userReadAllScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess
  $userReadAllScope.Id = "df021288-bdef-4463-88db-98f22de89214" # Well-known ID, the same across all tenants
  $userReadAllScope.Type = "Role" # Application permissions

  $graphRequiredResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRequiredResourceAccess.ResourceAccess = $userReadAllScope
  $graphRequiredResourceAccess.ResourceAppId = $graphServicePrincipal.AppId

  Write-Host "Creating worker application..."
  $workerApp = New-MgApplication `
    -DisplayName "Worker application" `
    -SignInAudience "AzureADandPersonalMicrosoftAccount" `
    -RequiredResourceAccess $graphRequiredResourceAccess

  Write-Host "Successfully created worker graph client app with clientId $($workerApp.AppId)"

  # Similar as with the UI, we need explicit service principal here.
  $workerServicePrincipal = New-MgServicePrincipal -AppId $workerApp.AppId

  # Create secret for the app. This has to be done after the app is created.
  $secret = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential
  $secret.KeyId = New-Guid
  $secret.DisplayName = "secret"

  Write-Host "Creating secret for the Worker application..."
  $secret = Add-MgApplicationPassword -ApplicationId $workerApp.Id -PasswordCredential $secret

  # Admin Consent - for Microsoft Graph this is a role assignment
  Write-Host "Updating admin consent for the Worker app..."

  New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $workerServicePrincipal.Id `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $userReadAllScope.Id `
    -PrincipalId $workerServicePrincipal.Id | Out-Null

  Write-Host "*** Azure AD Application '$($workerApp.DisplayName)' created."
  Write-Host "*** Client ID: $($workerApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID     = $workerApp.AppId
    ClientSecret = $secret.SecretText
  }
}