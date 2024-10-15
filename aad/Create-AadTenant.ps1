[CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
param (
  [Parameter(Mandatory = $false, HelpMessage = "Tenant name, without the '.onmicrosoft.com'.")]
  [string] $TenantName, # = "apiMngEnv019702v002",
    
  [Parameter(Mandatory = $false, HelpMessage = "Friendly name of the app registration.")]
  [string] $AppName, # = "ADO AAD Graph Client_001",

  [Parameter(HelpMessage = "Full ADO organization name, including https://. Example: https://dev.azure.com/myorg")]
  [string] $AdoOrganization, # = "https://dev.azure.com/MngEnv019702",

  [Parameter(HelpMessage = "ADO project name. Typically follows the organization name in the URL.")]
  [string] $AdoProjectName,

  [Parameter(HelpMessage = "Personal Access Token which grants access to variable groups and secret files.")]
  [string] $AdoPAT,

  [Parameter(HelpMessage = "Variable group in which service principal information will be stored. Will be created if it doesn't exist.")]
  [string] $AdoVariableGroupName, # = "AAD Service Principal 001",

  [Parameter(HelpMessage = "If set, certificate files (CER, PFX) will NOT be deleted after the certificate is uploaded to AAD and ADO.")]
  [switch] $KeepCertificates,
  
  [string] $ApimServiceNameDev,
  [string] $ApimServiceNamePrd,
  [switch] $UseGitHub
)

if ($UseGitHub -eq $false) {
  Write-Host "Using Azure DevOps Repositories"
  $UseGitHub = $false
}
else {
  Write-Host "Using GitHub Repositories"
  $UseGitHub = $true
}

if ([string]::IsNullOrWhiteSpace($AdoPAT)) {
  if ($UseGitHub -eq $false) {
    Write-Host "ADO PAT is not set. Trying to get it from environment..."
    $AdoPAT = $Env:ADO_PAT_B2C
    #Write-Host "ADO PAT: $AdoPAT" #CAREFUL: do not show this in production
  }
  else {
    Write-Host "GitHub PAT is not set. Trying to get it from environment..."
    $AdoPAT = $Env:GITHUB_PAT_B2C
    #Write-Host "GitHub PAT: $AdoPAT" #CAREFUL: do not show this in production
  }
}
else {
  if ($UseGitHub -eq $false) {
    Write-Host "ADO PAT was passed in as a parameter."
  }
  else {
    Write-Host "GitHub PAT was passed in as a parameter."
  }
}

Write-Host "Clearing Azure context..."
az account clear
az login --tenant "$($TenantName).onmicrosoft.com" --allow-no-subscriptions # to new child tenant

Write-Host "Creating AAD tenant $TenantName ..."
. ./Create-AzureAAD.ps1
#./Create-AadTenant -TenantName apiMngEnv019702 -AppName "ADO AAD Graph Client_001" -AdoOrganization "https://dev.azure.com/MngEnv019702" -AdoProjectName "APIM Azure AD B2C" -AdoVariableGroupName "AAD Service Principal 001"


if (Get-Module -ListAvailable -Name Microsoft.Graph) {
  Write-Host "Module Microsoft.Graph exists."
}
else {
  throw "Module Microsoft.Graph is not installed yet. Please install it first! Run 'Install-Module Microsoft.Graph'."
}  

# Call the init API
$aadExtensionsApp = Invoke-TenantInit `
  -TenantName $TenantName
    
#Write-Host "Interactive login to the Graph API. Watch for a newly opened browser window (or device flow instructions) and complete the sign in."
# Interactive login, so that we don't have to create a separate service principal and handle secrets.
# Make sure that the user has administrative permissions in the tenant.
      
# if re-run login to aad tenant
$loginInteractively = $false

if ($loginInteractively) {
  az login --scope https://management.core.windows.net//.default --tenant "$($TenantName).onmicrosoft.com" --allow-no-subscriptions
  Connect-MgGraph -TenantId "$($TenantName).onmicrosoft.com" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"
}
else {
  $TenantId = "$($TenantName).onmicrosoft.com"
  Get-AzTenant
  $TenantId = (get-aztenant | Where-Object { $_.Domains -match "$TenantId" }).Id
  Write-Host "AAD Tenant ID: $TenantId"

  . .\Connect-MgGraphWorkaround.ps1 # workaround for Connect-MgGraph bug use app registration
  $retValue = Get-AccessToken -ClientId "$($aadExtensionsApp.ClientID)" `
    -ClientSecret  "$($aadExtensionsApp.ClientSecret)" `
    -TenantId $TenantId 

  $accessToken = $retValue.AccessToken

  # Authenticate to the Microsoft Graph
  Connect-MgGraph -AccessToken $accessToken

  # Get Context
  Get-MgContext
}

$title = 'Confirm'
$question = 'In order to add custom attributes you need a P2 AAD. Are you ready to continue?'
$choices = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
  Write-Host 'Your choice is Yes.'
  # Add custom attribute called "ApiMaster"
  #Invoke-WebRequest : {"message":"An error has occurred.","exceptionMessage":"Authorization failed. 
  #You must use a User Access token to call this 
  #need an actual user e.g. a global admin

  $AttributeSetName = "ApiConsumers"
  $AttributeName = "ApiMaster"

  try {
    Write-Host "Adding custom attribute set '$AttributeSetName'..."
    Add-CustomAttributeSet `
      -TenantName $TenantName `
      -managementAccessToken $accessToken `
      -AttributeSetName $AttributeSetName `
      -Description "Attributes for $AttributeSetName team" `
      -maxAttributesPerSet 25
  }
  catch {
    Write-Host "Perhaps the attribute set $AttributeSetName already exists?"
  }

  try {
    Write-Host "Adding custom attribute '$AttributeName'..."  
    Add-CustomAttribute `
      -TenantName $TenantName `
      -managementAccessToken $accessToken `
      -AttributeSetName "$AttributeSetName" `
      -AttributeName $AttributeName `
      -Description "Indicates whether this user has API Master privileges" `
      -DataType "Boolean"
  }
  catch {
    Write-Host "Perhaps the attribute $AttributeName already exists in attribute set $AttributeSetName ?"
  }

}
else {
  Write-Host 'Your choice is No. Skipping adding custom attributes.'
}


#Write-Host $createdAdminUsers

#$AppName = "ADO Graph Client_003"
$TenantId = "$($TenantName).onmicrosoft.com"

Write-Host "Creating service principal $AppName..."
. ./Create-ServicePrincipal.ps1

if ($loginInteractively) {
  az login --scope https://management.core.windows.net//.default --tenant "$($TenantName).onmicrosoft.com" --allow-no-subscriptions
  Connect-MgGraph -TenantId "$($TenantName).onmicrosoft.com" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"
}
else {
  $TenantId = "$($TenantName).onmicrosoft.com"
  Get-AzTenant
  $TenantId = (get-aztenant | Where-Object { $_.Domains -match "$TenantId" }).Id
  Write-Host "AAD Tenant ID: $TenantId"

  . .\Connect-MgGraphWorkaround.ps1 # workaround for Connect-MgGraph bug use app registration
  $retValue = Get-AccessToken -ClientId "$($aadExtensionsApp.ClientID)" `
    -ClientSecret  "$($aadExtensionsApp.ClientSecret)" `
    -TenantId $TenantId 

  $accessToken = $retValue.AccessToken

  # Authenticate to the Microsoft Graph
  Connect-MgGraph -AccessToken $accessToken

  # Get Context
  Get-MgContext
}

# Create demo users
. ./Create-Users.ps1 # dot-sourcing only now, to prevent interference with the previous steps

$createdAdminUsers = Import-Users `
  -TenantName $TenantName `
  -UsersFilePath "usersAdmin.json" `
  -managementAccessToken $accessToken

Write-Host "create identity provider apps - CAREFUL will re-create each time! may not want this behaviour in PROD"
. ./Create-AadIdentityProvider.ps1 

$idpAppDev = New-AadIdentityProviderApp `
  -TenantName $TenantName `
  -ApimServiceName $ApimServiceNameDev `
  -SkipConnectMgGraph

$idpAppPrd = New-AadIdentityProviderApp `
  -TenantName $TenantName `
  -ApimServiceName $ApimServiceNamePrd `
  -SkipConnectMgGraph

Write-Host "Waiting for 30 seconds for AAD Identity Provider app registration creation..."
Start-Sleep -Seconds 30
  
$idpClientSecretDev = $idpAppDev.ClientSecret
$idpClientIdDev = $idpAppDev.ClientID
$idpAppDisplayNameDev = $idpAppDev.DisplayName

$idpClientSecretPrd = $idpAppPrd.ClientSecret
$idpClientIdPrd = $idpAppPrd.ClientID
$idpAppDisplayNamePrd = $idpAppPrd.DisplayName

$createdAdminUsersPassword = $createdAdminUsers.password
$userPasswordAsSecureString = ConvertTo-SecureString "$createdAdminUsersPassword" -AsPlainText -Force

$aadExtensionsAppClientId = "$($aadExtensionsApp.ClientID)" 
$aadExtensionsAppClientSecret = "$($aadExtensionsApp.ClientSecret)" 

New-ServicePrincipal -AppName $AppName `
  -TenantName $TenantName `
  -TenantId $TenantId `
  -AdoPAT $AdoPAT `
  -AdoOrganization $AdoOrganization `
  -AdoProjectName "$AdoProjectName" `
  -AdoVariableGroupName "$AdoVariableGroupName" `
  -userId $createdAdminUsers.email `
  -userPassword $userPasswordAsSecureString `
  -aadExtensionsAppClientId $aadExtensionsAppClientId `
  -aadExtensionsAppClientSecret $aadExtensionsAppClientSecret `
  -idpClientSecretDev $idpClientSecretDev `
  -idpClientIdDev $idpClientIdDev `
  -idpAppDisplayNameDev $idpAppDisplayNameDev `
  -idpClientSecretPrd $idpClientSecretPrd `
  -idpClientIdPrd $idpClientIdPrd `
  -idpAppDisplayNamePrd $idpAppDisplayNamePrd `
  -UseGitHub $UseGitHub

#-CertPath ./cert.cer    

Write-Host "Done. Don't forget to give admin privileges to aad api admin user in AAD."
$userId = $createdAdminUsers.email
$userPassword = $createdAdminUsers.password
Write-Host "COMMAND: az login -u `"$userId`" -p `"$userPassword`" --scope `"https://management.core.windows.net//.default`" --tenant `"$TenantId`" --allow-no-subscriptions"
Write-Host "sanity check login"
try {
  az login -u "$userId" -p "$userPassword" --scope "https://management.core.windows.net//.default" --tenant "$TenantId" --allow-no-subscriptions 
}
catch {
  Write-Host "If you see an error such as: AADSTS50126: Error validating credentials due to invalid username or password."
  Write-Host "It means that you may need to reset the password to the one above."
}