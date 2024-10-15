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
  
  [Parameter(Mandatory = $true, HelpMessage = "Friendly name of the app registration.")]
  [string] $AppName,

  #[Parameter(Mandatory = $true, HelpMessage = "Your Azure Active Directory B2C tenant ID.")]
  #[string] $TenantId,

  [Parameter(HelpMessage = "Full ADO organization name, including https://. Example: https://dev.azure.com/myorg")]
  [string] $AdoOrganization,

  [Parameter(HelpMessage = "ADO project name. Typically follows the organization name in the URL.")]
  [string] $AdoProjectName,

  [Parameter(HelpMessage = "Personal Access Token which grants access to variable groups and secret files.")]
  [string] $AdoPAT,

  [Parameter(HelpMessage = "Variable group in which service principal information will be stored. Will be created if it doesn't exist.")]
  [string] $AdoVariableGroupName,

  [Parameter(HelpMessage = "If set, certificate files (CER, PFX) will NOT be deleted after the certificate is uploaded to AAD and ADO.")]
  [switch] $KeepCertificates
)

if ([string]::IsNullOrWhiteSpace($AdoPAT)) {
  Write-Host "ADO PAT is not set. Trying to get it from environment..."
  $AdoPAT = $Env:ADO_PAT_B2C
  #Write-Host "ADO PAT: $AdoPAT" #CAREFUL: do not show this in production
}
else {
  Write-Host "ADO PAT was passed in as a parameter."
}

Write-Host "Clearing Azure context..."
az account clear
az login # to main parent tenant

Write-Host "Creating B2C tenant $B2CTenantName in resource group $ResourceGroupName..."
. ./Create-AzureB2C.ps1
#./Create-B2CTenant -B2CTenantName testekb2c002 -ResourceGroupName rg-b2ctenant-002 -Location "United States" -CountryCode "CA" -ResourceGroupLocation "canadacentral"


if (Get-Module -ListAvailable -Name Microsoft.Graph) {
  Write-Host "Module Microsoft.Graph exists."
}
else {
  throw "Module Microsoft.Graph is not installed yet. Please install it first! Run 'Install-Module Microsoft.Graph'."
}  
    
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
    
#Write-Host "Interactive login to the Graph API. Watch for a newly opened browser window (or device flow instructions) and complete the sign in."
# Interactive login, so that we don't have to create a separate service principal and handle secrets.
# Make sure that the user has administrative permissions in the tenant.
      
# if re-run login to b2c tenant
az login --scope https://management.core.windows.net//.default --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
      
Connect-MgGraph -TenantId "$($B2CTenantName).onmicrosoft.com" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"

# Add custom attribute called "ApiMaster"
#Invoke-WebRequest : {"message":"An error has occurred.","exceptionMessage":"Authorization failed. 
#You must use a User Access token to call this 
#need an actual user e.g. a global admin

try {
  Write-Host "Adding custom attribute 'ApiMaster'..."
  Add-CustomAttribute `
    -B2CTenantName $B2CTenantName `
    -AttributeName "ApiMaster" `
    -Description "Indicates whether this user has API Master privileges"
}
catch {
  Write-Host "Perhaps the attribute already exists?"
}

# Create demo users
. ./Create-Users.ps1 # dot-sourcing only now, to prevent interference with the previous steps

$createdAdminUsers = Import-Users `
  -B2CTenantName $B2CTenantName `
  -UsersFilePath "usersAdmin.json"

#Write-Host $createdAdminUsers

#$AppName = "ADO Graph Client_003"
$TenantId = "$($B2CTenantName).onmicrosoft.com"

Write-Host "Creating service principal $AppName..."
. ./Create-ServicePrincipal.ps1

$createdAdminUsersPassword = $createdAdminUsers.password
$userPasswordAsSecureString = ConvertTo-SecureString "$createdAdminUsersPassword" -AsPlainText -Force

New-ServicePrincipal -AppName $AppName `
  -B2CTenantName $B2CTenantName `
  -TenantId $TenantId `
  -AdoPAT $AdoPAT `
  -AdoOrganization $AdoOrganization `
  -AdoProjectName "$AdoProjectName" `
  -AdoVariableGroupName "$AdoVariableGroupName" `
  -userId $createdAdminUsers.email `
  -userPassword $userPasswordAsSecureString

#-CertPath ./cert.cer    

Write-Host "Done. Don't forget to give admin privileges to b2c admin user in AAD."
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