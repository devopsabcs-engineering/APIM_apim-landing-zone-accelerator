# Windows PowerShell and PowerShell Core are supported.
# - Microsoft.Graph PowerShell module needs to be installed.
# - Azure CLI needs to be installed and authenticated for the owning tenant.
#
# Usage:
# - dot-source in a PS script: . ./Create-AzureB2C.ps1
# - invoke individual functions, or the main one: Initialize-B2CTenant -B2CTenantName mytenant -ResourceGroupName myrg -Location "Europe" -CountryCode "CZ"

#Initialize-B2CTenant -B2CTenantName testek001b2c -ResourceGroupName rg-b2ctenant-001 -Location "United States" -CountryCode "CA" -ResourceGroupLocation "canadacentral"

function Initialize-B2CTenant {
  [CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
  param (
    [Parameter(Mandatory = $true, HelpMessage = "B2C tenant name, without the '.onmicrosoft.com'.")]
    [string] $B2CTenantName,
    
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group to put the B2C resource into. Will be created if it does not exist.")]
    [string] $ResourceGroupName,

    [string] $Location = "United States",

    [string] $ResourceGroupLocation = "canadacentral",
    
    [Parameter(HelpMessage = "Two letter country code (e.g. 'US', 'CZ', 'DE'). https://docs.microsoft.com/en-us/azure/active-directory-b2c/data-residency")]
    [string] $CountryCode = "CA",
    [Parameter(HelpMessage = "If set, will create B2C Tenant (requires interactive login). Will not create tenant if not set.")]
    [switch] $CreateB2cTenant,
    [Parameter(Mandatory = $true, HelpMessage = "Thumbprint for certificate to use with ms graph api.")]
    [string] $b2cAdoClientCertThumbprint,
    [Parameter(Mandatory = $true, HelpMessage = "b2cAdoClientId")]
    [string] $b2cAdoClientId,
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
    [string] $AdoVariableGroupNamePrd
  )

  Write-Host "Initializing B2C tenant $B2CTenantName in resource group $ResourceGroupName."
  Write-Host "org: $AdoOrganization and project: $AdoProjectName"

  if (Get-Module -ListAvailable -Name Microsoft.Graph) {
    Write-Host "Module Microsoft.Graph exists."
  }
  else {
    throw "Module Microsoft.Graph is not installed yet. Please install it first! Run 'Install-Module Microsoft.Graph'."
  }  

  if ($CreateB2cTenant) {
    
    # Create the B2C tenant resource in Azure
    New-AzureADB2CTenant `
      -B2CTenantName $B2CTenantName `
      -Location $Location `
      -CountryCode $CountryCode `
      -AzureResourceGroup $ResourceGroupName `
      -ResourceGroupLocation $ResourceGroupLocation

    # Call the init API
    Invoke-TenantInit `
      -B2CTenantName $B2CTenantName

    Write-Host "Interactive login to the Graph API. Watch for a newly opened browser window (or device flow instructions) and complete the sign in."
    # Interactive login, so that we don't have to create a separate service principal and handle secrets.
    # Make sure that the user has administrative permissions in the tenant.

    # if re-run login to b2c tenant
    #az login --scope https://management.core.windows.net//.default --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions

    Connect-MgGraph -TenantId "$($B2CTenantName).onmicrosoft.com" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"
  }
  else {
    Write-Host "*** Skipping creation of B2C tenant..."
    Write-Host "get all certs"
    Get-ChildItem Cert:\LocalMachine\My\
          
    # Authenticate
    $certInstore = Get-ChildItem "Cert:\LocalMachine\My\$b2cAdoClientCertThumbprint"
    Write-Host certificate $certInstore
    #az login --service-principal -u ${app_id} -p ${password} --tenant ${tenant_id}
    #az login --service-principal -u $clientId -p $clientSecret --scope "https://management.core.windows.net//.default" --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
    #az login --service-principal -u $clientId -p $clientSecret --scope "https://graph.microsoft.com/.default" --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
    Write-Host "logging in with user $userId"
    #ps 7
    #$plainTextUserPassword = ConvertFrom-SecureString -AsPlainText $userPassword
    #ps 5.1
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword)
    $plainTextUserPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    az login -u "$userId" -p "$plainTextUserPassword" --scope "https://management.core.windows.net//.default" --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
    Write-Host "DONE logging in with user $userId"
    Connect-MgGraph -ClientId $b2cAdoClientId -TenantId "$B2CTenantName.onmicrosoft.com" -Certificate $certInstore
    Get-MgContext
  }

  # # Add custom attribute called "ApiMaster"
  # #Invoke-WebRequest : {"message":"An error has occurred.","exceptionMessage":"Authorization failed. 
  # #You must use a User Access token to call this 
  # #need an actual user e.g. a global admin
  # Add-CustomAttribute `
  #   -B2CTenantName $B2CTenantName `
  #   -AttributeName "ApiMaster" `
  #   -Description "Indicates whether this user has API Master privileges"
      
  # # Add user signin user flow
  # Add-UserFlow `
  #   -B2CTenantName $B2CTenantName `
  #   -DefinitionFilePath ./SignIn-userflow.json

  # # Add ROPC signin user flow
  # Add-UserFlow `
  #   -B2CTenantName $B2CTenantName `
  #   -DefinitionFilePath ./ROPC-userflow.json

  try {
    # Add signup and signin user flow DEV
    Add-UserFlow `
      -B2CTenantName $B2CTenantName `
      -DefinitionTemplateFilePath ./SignUpSignIn-userflow.template.json `
      -environmentName "dev" `
      -userFlowId "frontendapp_dev_signupandsignin"
  }
  catch {
    Write-Host "Error when creating user flow, there's a chance it already exists."
  }  
  try {
    # Add signup and signin user flow PROD  
    Add-UserFlow `
      -B2CTenantName $B2CTenantName `
      -DefinitionTemplateFilePath ./SignUpSignIn-userflow.template.json `
      -environmentName "prd" `
      -userFlowId "frontendapp_prd_signupandsignin"
  }
  catch {
    Write-Host "Error when creating user flow, there's a chance it already exists."
  }  
  # # Create Application for the UI
  # $uiApp = New-UIApp `
  #   -B2CTenantName $B2CTenantName

  # Create Application for the Backend DEV
  $beAppDev = New-BackendApp `
    -B2CTenantName $B2CTenantName `
    -environmentName "dev"
  
  $BackendHelloScopeIdDev = $beAppDev.HelloScopeId
  $BackendAppAppIdDev = $beAppDev.ClientID
  $BackendServicePrincipalIdDev = $beAppDev.ServicePrincipalId

  # Create Application for the Backend PROD
  $beAppPrd = New-BackendApp `
    -B2CTenantName $B2CTenantName `
    -environmentName "prd"
  
  #az ad app show --id  $beApp.ClientID

  $BackendHelloScopeIdPrd = $beAppPrd.HelloScopeId
  $BackendAppAppIdPrd = $beAppPrd.ClientID
  $BackendServicePrincipalIdPrd = $beAppPrd.ServicePrincipalId
  
  # Create Application for the Frontend DEV
  $feAppDev = New-FrontendApp `
    -B2CTenantName $B2CTenantName `
    -BackendHelloScopeId $BackendHelloScopeIdDev `
    -BackendAppAppId $BackendAppAppIdDev `
    -BackendServicePrincipalId $BackendServicePrincipalIdDev `
    -environmentName "dev"

  # Create Application for the Frontend PROD  
  $feAppPrd = New-FrontendApp `
    -B2CTenantName $B2CTenantName `
    -BackendHelloScopeId $BackendHelloScopeIdPrd `
    -BackendAppAppId $BackendAppAppIdPrd `
    -BackendServicePrincipalId $BackendServicePrincipalIdPrd `
    -environmentName "prd"

  # Create Application for the Frontend API Management DEV
  $feApimAppDev = New-FrontendApimDevPortalApp `
    -B2CTenantName $B2CTenantName `
    -BackendHelloScopeId $BackendHelloScopeIdDev `
    -BackendAppAppId $BackendAppAppIdDev `
    -BackendServicePrincipalId $BackendServicePrincipalIdDev `
    -environmentName "dev"

  # Create Application for the Frontend API Management PROD
  $feApimAppPrd = New-FrontendApimDevPortalApp `
    -B2CTenantName $B2CTenantName `
    -BackendHelloScopeId $BackendHelloScopeIdPrd `
    -BackendAppAppId $BackendAppAppIdPrd `
    -BackendServicePrincipalId $BackendServicePrincipalIdPrd `
    -environmentName "prd"

  # # Create the Graph Client application for the Worker
  # $workerApp = New-WorkerApp

  # Create demo users
  . ./Create-Users.ps1 # dot-sourcing only now, to prevent interference with the previous steps

  try {
    $createdUsers = Import-Users `
      -B2CTenantName $B2CTenantName
  }
  catch {
    Write-Host "Error when creating users, there's a chance they've already been created."
  }  

  # TODO: Integrate Create-ServicePrincipal.ps1
  . ./Create-ServicePrincipal.ps1

  # Update variable groups DEV
  #APIM_b2c_frontend_dev_vars
  $api_scopes = "https://$B2CTenantName.onmicrosoft.com/$BackendAppAppIdDev/Hello"
  $msal_auth_authority = "https://$B2CTenantName.b2clogin.com/tfp/$B2CTenantName.onmicrosoft.com/b2c_1_frontendapp_dev_signupandsignin"
  $msal_auth_clientid = $feAppDev.ClientID
  $msal_auth_known_authorities = "$B2CTenantName.b2clogin.com"
  $beClientSecret = $beAppDev.ClientSecret
  $beClientId = $beAppDev.ClientID
  $apimFrontendClientId = $feApimAppDev.ClientID
  $apimFrontendClientSecret = $feApimAppDev.ClientSecret
  $adoVarsDev = @{
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
  # Update-ADO `
  #   -PatToken $AdoPAT `
  #   -OrganizationUrl $AdoOrganization `
  #   -Project $AdoProjectName `
  #   -VariableGroupName $AdoVariableGroupNameDev `
  #   -Variables $adoVarsDev

  # Update variable groups PROD
  #APIM_b2c_frontend_prod_vars
  $api_scopes = "https://$B2CTenantName.onmicrosoft.com/$BackendAppAppIdPrd/Hello"
  $msal_auth_authority = "https://$B2CTenantName.b2clogin.com/tfp/$B2CTenantName.onmicrosoft.com/b2c_1_frontendapp_prd_signupandsignin"
  $msal_auth_clientid = $feAppPrd.ClientID
  $msal_auth_known_authorities = "$B2CTenantName.b2clogin.com"
  $beClientSecret = $beAppPrd.ClientSecret
  $beClientId = $beAppPrd.ClientID
  $apimFrontendClientId = $feApimAppPrd.ClientID
  $apimFrontendClientSecret = $feApimAppPrd.ClientSecret
  $adoVarsPrd = @{
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
# Create new Azure AD B2C tenant in a specific subscription and resource group.
# Must be followed by Invoke-TenantInit to finalize the creation of default apps.
#
# Required: Azure CLI authenticated for the target subscription.
# Required: Resource provider: "Microsoft.AzureActiveDirectory". The function will attempt to register if not done so yet.
#   az provider register --namespace Microsoft.AzureActiveDirectory
#
# Azure PowerShell Alternative: Invoke-AzRestMethod
function New-AzureADB2CTenant {
  param(
    # Tenant name without the '.onmicrosoft.com' part.
    [string] $B2CTenantName,

    # Can be one of 'United States', 'Europe', 'Asia Pacific', or 'Australia' (preview).
    [Parameter()]
    [ValidateSet('United States', 'Europe', 'Asia Pacific', 'Australia')]
    [string] $Location,

    [string] $ResourceGroupLocation = "canadacentral",

    # Where data resides. Two letter country code (e.g. 'US', 'CZ', 'DE').
    # Valid country codes are listed here: https://docs.microsoft.com/en-us/azure/active-directory-b2c/data-residency
    [string] $CountryCode,

    # Under which Azure subscription will this B2C tenant reside. If not provided, use the current subscription from Azure CLI.
    [string] $AzureSubscriptionId = $null,

    # Under which Azure resource group will this B2C tenant reside.
    [string] $AzureResourceGroup
  )

  if (!$AzureSubscriptionId) {
    Write-Host "Getting subscription ID from the current account..."
    $AzureSubscriptionId = $(az account show --query "id" -o tsv)
    Write-Host $AzureSubscriptionId
  }

  $aadProviderRegState = $(az provider show -n Microsoft.AzureActiveDirectory --query "registrationState" -o tsv)
  if ($aadProviderRegState -ne "Registered") {
    Write-Host "Resource Provider 'Microsoft.AzureActiveDirectory' not registered yet. Registering now..."
    az provider register --namespace Microsoft.AzureActiveDirectory

    while ($(az provider show -n Microsoft.AzureActiveDirectory --query "registrationState" -o tsv) -ne "Registered") {
      Write-Host "Resource Provider registration not yet finished. Waiting..."
      Start-Sleep -Seconds 10
    }
    Write-Host "Resource Provider registration finished."
  }

  Write-Host "Checking if Resource Group $AzureResourceGroup exists..."
  $checkRg = az group exists --name $AzureResourceGroup | ConvertFrom-Json

  if ($LastExitCode -ne 0) {
    throw "Error on using Azure CLI. Make sure the CLI is installed, up-to-date and you are signed in. Run 'az login' to sign in."
  }

  if (!$checkRg) {
    Write-Warning "Resource Group $AzureResourceGroup does not exist. Creating..."
    az group create --name $AzureResourceGroup --location $ResourceGroupLocation # Everybody likes Ireland, so we put the RG there if it does not exist
  }

  $resourceId = "/subscriptions/$AzureSubscriptionId/resourceGroups/$AzureResourceGroup/providers/Microsoft.AzureActiveDirectory/b2cDirectories/$B2CTenantName.onmicrosoft.com"

  # Check if tenant already exists
  Write-Host "Checking if tenant '$B2CTenantName' already exists..."
  az resource show --id $resourceId | Out-Null
  if ($LastExitCode -eq 0) {
    # No error means, the resource exists
    Write-Warning "Tenant '$B2CTenantName' already exists. Not attempting to recreate it."
    return
  }

  $reqBody = @"
  {
    "location":"$($Location)",
    "sku": {
        "name":"Standard",
        "tier":"A0"
    },
    "properties": {
        "createTenantProperties": {
            "displayName":"$($B2CTenantName)",
            "countryCode":"$($CountryCode)"
        }
    }
  }
"@ # No whitespace permitted before the closing sequence.

  # Flatten the JSON to make Azure CLI happy, otherwise it complains about incorrect content type.
  $reqBody = $reqBody.Replace("`n", "").Replace("`"", "\`"")

  Write-Host "Creating B2C tenant $B2CTenantName..."
  # https://docs.microsoft.com/en-us/rest/api/activedirectory/b2c-tenants/create
  az rest --method PUT --url "https://management.azure.com$($resourceId)?api-version=2019-01-01-preview" --body $reqBody

  if ($LastExitCode -ne 0) {
    throw "Error on creating new B2C tenant!"
  }

  Write-Host "*** B2C Tenant creation started. It can take a moment to complete."

  do {
    Write-Host "Waiting for 30 seconds for B2C tenant creation..."
    Start-Sleep -Seconds 30

    az resource show --id $resourceId
  }
  while ($LastExitCode -ne 0)
}

#
# Finalize initialization of newly created B2C tenant.
# This function needs to be called once the tenant is created and before any other steps, because it creates the b2c-extensions-app.
#
# Required: Azure CLI authenticated with owner permissions for the tenant.
function Invoke-TenantInit {
  param (
    [string] $B2CTenantName
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"
  Get-AzTenant
  $B2CTenantId = (get-aztenant | Where-Object { $_.Domains -match "$B2CTenantId" }).Id
  Write-Host "B2C Tenant ID: $B2CTenantId"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant "$B2CTenantId" --query accessToken -o tsv)

  # Invoke tenant initialization which happens through the portal automatically.
  # Ref: https://stackoverflow.com/questions/67706798/creation-of-the-b2c-extensions-app-by-script
  Write-Host "Invoking tenant initialization..."
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/tenants/GetAndInitializeTenantPolicy?tenantId=$($B2CTenantId)&skipInitialization=false" `
    -Method "GET" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)"
  }
}

#
# Create a custom user attribute in the tenant.
#
# Requires: Azure CLI authenticated with owner permissions for the tenant.
# Alternatively, the /beta/identity/userFlowAttributes Graph endpoint can be used.
function Add-CustomAttribute {
  param (
    [string] $B2CTenantName,
    
    [string] $AttributeName,
    [string] $Description,
    [string] $DataType = 2
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"
  Get-AzTenant
  $B2CTenantId = (get-aztenant | Where-Object { $_.Domains -match "$B2CTenantId" }).Id
  Write-Host "B2C Tenant ID: $B2CTenantId"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant $B2CTenantId --query accessToken -o tsv)
  $reqBody = @"
{
  "dataType": $($DataType),
  "label": "$($AttributeName)",
  "adminHelpText": "$($Description)",
  "userInputType": 1,
  "userAttributeOptions": [],
  "attributeType": 3
}
"@ # no whitespace permitted before the closing sequence

  # Create the attribute using the same method as the Portal.
  Write-Host "Creating custom attribute $($AttributeName)..."
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/userAttribute?tenantId=$($B2CTenantId)" `
    -Method "POST" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)";
    "Content-Type"  = "application/json"
  } `
    -Body $reqBody
}

#
# Create user flow based on JSON definition from a file.
#
# Requires: Azure CLI authenticated with owner permissions for the tenant.
function Add-UserFlow {
  param(
    [string] $B2CTenantName,
    [string] $DefinitionTemplateFilePath,
    [string] $environmentName,
    [string] $userFlowId
  )

  $userFlow = Get-Content $DefinitionTemplateFilePath
  $userFlow = $userFlow.Replace('__USER_FLOW_ID__', $userFlowId) # replace the placeholder with the actual B2C tenant name

  Write-Host $userFlow 
  $DefinitionFilePath = $DefinitionTemplateFilePath.Replace('.template', ".${environmentName}")
  $userFlow | Out-File -FilePath $DefinitionFilePath

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant $B2CTenantId --query accessToken -o tsv)

  Write-Host "Creating $($DefinitionFilePath) user flow..."
  $signinFlowContent = Get-Content $DefinitionFilePath
  # Using WebRequest here, because Microsoft Graph is currently not able to create user flows with custom attributes.
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/adminuserjourneys?tenantId=$($B2CTenantId)" `
    -Method "POST" `
    -Headers @{
    "Authorization" = "Bearer $($managementAccessToken)";
    "Content-Type"  = "application/json"
  } `
    -Body $signinFlowContent
}

#
# Creates a B2C application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-UIApp {
  param (
    [string] $B2CTenantName
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
    -IdentifierUris "https://$($B2CTenantName).onmicrosoft.com/$($uiApp.AppId)"

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

  Write-Host "*** Azure AD B2C Application '$($uiApp.DisplayName)' created."
  Write-Host "*** Client ID: $($uiApp.AppId)"

  return @{
    ClientID = $uiApp.AppId
  }
}

#
# Creates a B2C application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-BackendApp {
  param (
    [string] $B2CTenantName,
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
    -IdentifierUris "https://$($B2CTenantName).onmicrosoft.com/$($beApp.AppId)"

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

  Write-Host "*** Azure AD B2C Application '$($beApp.DisplayName)' created."
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
# Creates a B2C application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-FrontendApp {
  param (
    [string] $B2CTenantName,
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
  #    -IdentifierUris "https://$($B2CTenantName).onmicrosoft.com/$($feApp.AppId)"

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
  # need to connect to newly create b2c tenant to grab service principal id aka object id for 'Microsoft Graph'
  #az login --scope https://management.core.windows.net//.default --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
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

  Write-Host "*** Azure AD B2C Application '$($feApp.DisplayName)' created."
  Write-Host "*** Client ID: $($feApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID     = $feApp.AppId
    ClientSecret = $secret.SecretText
  }
}

#
# Creates a B2C application registration to be used for users to sign-in.
#
# This includes custom scope called Apis.Access.
#
function New-FrontendApimDevPortalApp {
  param (
    [string] $B2CTenantName,
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
  #    -IdentifierUris "https://$($B2CTenantName).onmicrosoft.com/$($feApp.AppId)"

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
  # need to connect to newly create b2c tenant to grab service principal id aka object id for 'Microsoft Graph'
  #az login --scope https://management.core.windows.net//.default --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
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

  Write-Host "*** Azure AD B2C Application '$($feApimApp.DisplayName)' created."
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

  Write-Host "*** Azure AD B2C Application '$($workerApp.DisplayName)' created."
  Write-Host "*** Client ID: $($workerApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID     = $workerApp.AppId
    ClientSecret = $secret.SecretText
  }
}