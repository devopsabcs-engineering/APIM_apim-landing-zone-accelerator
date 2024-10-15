# For app-only authentication with Microsoft Graph a service principal must exist, with certificate authentication and admin consent for the required scopes.
# https://docs.microsoft.com/en-us/graph/powershell/app-only?tabs=azure-portal
#
# Usage:
#   . ./CreateServicePrincipal.ps1
#   New-ServicePrincipal -AppName "ADO Graph Client" -CertPath ./cert.cer -TenantId "mytenant.onmicrosoft.com" 

function New-ServicePrincipal {

  param(
    [Parameter(Mandatory = $true, HelpMessage = "Friendly name of the app registration.")]
    [string] $AppName,

    [Parameter(Mandatory = $true, HelpMessage = "Your Azure Active Directory B2C tenant ID.")]
    [string] $B2CTenantName,

    [Parameter(Mandatory = $true, HelpMessage = "Your Azure Active Directory B2C tenant ID.")]
    [string] $TenantId,

    [Parameter(HelpMessage = "Full ADO organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $AdoOrganization,

    [Parameter(HelpMessage = "ADO project name. Typically follows the organization name in the URL.")]
    [string] $AdoProjectName,

    [Parameter(HelpMessage = "Personal Access Token which grants access to variable groups and secret files.")]
    [string] $AdoPAT,

    [Parameter(HelpMessage = "Variable group in which service principal information will be stored. Will be created if it doesn't exist.")]
    [string] $AdoVariableGroupName,

    #[Parameter(HelpMessage = "Secure File Name which contains pfx cert. Will be created if it doesn't exist.")]
    #[string] $AdoSecureFileName,

    [Parameter(HelpMessage = "If set, certificate files (CER, PFX) will NOT be deleted after the certificate is uploaded to AAD and ADO.")]
    [switch] $KeepCertificates,
    [Parameter(Mandatory = $true, HelpMessage = "userId")]
    [string] $userId,
    [Parameter(Mandatory = $true, HelpMessage = "userPassword")]
    [securestring] $userPassword
  )

  # Stop when PowerShell commandlets encounter an error - doesn't help with az CLI errors.
  $ErrorActionPreference = "Stop"

  # Graph permissions constants
  $graphResourceId = "00000003-0000-0000-c000-000000000000"
  $applicationReadWriteAll = @{
    Id   = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9" # "Application.ReadWrite.All", well-known ID across all B2C tenants
    Type = "Role"
  }
  $directoryReadWriteAll = @{
    Id   = "19dbc75e-c2e2-444c-a770-ec69d8559fc7"
    Type = "Role"
  }

  #Connect-MgGraph -Scopes "Application.ReadWrite.All User.Read" -TenantId $TenantId
  #actually to be able to grant admin consent, you need these scopes:
  Connect-MgGraph -TenantId $TenantId  -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"

  Write-Host "Creating new certificate..."
  $createdCert = New-Certificate -CertificateName $AppName -ExportDirectoryPath "./" # this also prints the path and password to console
  $CertPath = $createdCert.cerPath | Resolve-Path
  
  Write-Host "CertPath: $CertPath."
    
  # Load cert
  $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
  Write-Host "Certificate loaded into memory."

  # Inline (dictionary) version doesn't work in this case...
  $graphRequiredResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRequiredResourceAccess.ResourceAccess = @($applicationReadWriteAll, $directoryReadWriteAll) #multiple graph scopes
  $graphRequiredResourceAccess.ResourceAppId = $graphResourceId

  # Create app registration
  #   "AzureADMyOrg" is a constant, don't change
  #   "RedirectUris" cannot be empty - using localhost to start with
  Write-Host "Creating app registration..."
  $appRegistration = New-MgApplication `
    -DisplayName $AppName `
    -SignInAudience "AzureADMyOrg" `
    -Web @{ RedirectUris = "http://localhost"; } `
    -RequiredResourceAccess $graphRequiredResourceAccess `
    -AdditionalProperties @{} `
    -KeyCredentials @(@{ Type = "AsymmetricX509Cert"; Usage = "Verify"; Key = $certificate.RawData })

  Write-Host "*** App registration created with App ID:" $appRegistration.AppId

  # Create corresponding service principal
  Write-Host "Creating service principal..."
  $appServicePrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId -AdditionalProperties @{}
  Write-Host "Service principal created."

  # Grant admin consent
  Write-Host "Granting admin consent..."
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

  #$TenantId = "testekb2c002.onmicrosoft.com" # "$($B2CTenantName).onmicrosoft.com"
  #Connect-MgGraph -Scopes "Application.ReadWrite.All User.Read" -TenantId $TenantId
  #Get-MgServicePrincipal
  #75d45447-4fbe-4855-ada9-ada857b28054 is object id of corresponding enterprise application aka corresponding service principal
  #Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId 75d45447-4fbe-4855-ada9-ada857b28054
  # New-MgServicePrincipalAppRoleAssignment `
  #   -ServicePrincipalId 75d45447-4fbe-4855-ada9-ada857b28054 `
  #   -PrincipalId 75d45447-4fbe-4855-ada9-ada857b28054 `
  #   -ResourceId eb4afc9d-1c3f-45ed-8c0a-d140e70c97ed `
  #   -appRoleId 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9
  #get New-MgServicePrincipalAppRoleAssignment_CreateExpanded1: Insufficient privileges to complete the operation.
  #missing scopes e.g. "Directory.ReadWrite.All"
  #https://stackoverflow.com/questions/71228350/how-to-grant-a-service-principal-permissions-to-run-get-azadserviceprincipal
  
  New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $appServicePrincipal.Id `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $applicationReadWriteAll.Id `
    -PrincipalId $appServicePrincipal.Id | Out-Null

  New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $appServicePrincipal.Id `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $directoryReadWriteAll.Id `
    -PrincipalId $appServicePrincipal.Id | Out-Null

  #ps 7
  #$plainTextUserPassword = ConvertFrom-SecureString -AsPlainText $userPassword
  #ps 5.1
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword)
  $plainTextUserPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    
  $adoVars = @{
    b2cTenantName              = @{ value = $B2CTenantName; secret = "false" };
    b2cAdoClientId             = @{ value = $appRegistration.AppId; secret = "false" };
    b2cAdoClientCertName       = @{ value = $createdCert.certName; secret = "false" };
    b2cAdoClientCertThumbprint = @{ value = $certificate.Thumbprint; secret = "false" };
    b2cAdoClientCertPassword   = @{ value = $createdCert.password; secret = "true" };
    userId                     = @{ value = $userId; secret = "false" };
    userPassword               = @{ value = $plainTextUserPassword; secret = "false" }; #not secret, just for testing
    adoPAT                     = @{ value = $AdoPAT; secret = "true" }
  }

  # Update variable groups and upload certificate
  Update-ADO `
    -PatToken $AdoPAT `
    -OrganizationUrl $AdoOrganization `
    -Project $AdoProjectName `
    -VariableGroupName $AdoVariableGroupName `
    -Variables $adoVars `
    -SecureFileName "$($createdCert.certName)" `
    -SecureFileLocalPath "$($createdCert.pfxPath)"

  Disconnect-MgGraph
  Write-Host "Microsoft Graph session disconnected."

  Write-Host
  Write-Host "*** App ID: $($appRegistration.AppId)"

  if ($KeepCertificates) {
    Write-Host "*** Certificate name:         $($createdCert.certName)"
    Write-Host "*** Certificate public key:   $($createdCert.cerPath)"
    Write-Host "*** Certificate private key:  $($createdCert.pfxPath)"
    Write-Host "*** Certificate password:     $($createdCert.password)"
  }
  else {
    Write-Host "*** Removing certificate files..."
    Remove-Item $createdCert.cerPath
    Remove-Item $createdCert.pfxPath
  }

  # Finish with empty line.
  Write-Host
}

function New-Certificate {
  [CmdletBinding()]
  param (
    [Parameter(HelpMessage = "Certificate name which will be used for the exported cert filename.")]
    [string] $CertificateName,
    
    [Parameter(HelpMessage = "Path to the directory where generated certificate and private key will be stored.")]
    [string] $ExportDirectoryPath
  )

  # Remove spaces from the certificate name and also all file names.
  $CertificateName = $CertificateName.Replace(" ", "_")

  $cerPath = Join-Path -Path $ExportDirectoryPath -ChildPath "$($CertificateName).cer"
  $pfxPath = Join-Path -Path $ExportDirectoryPath -ChildPath "$($CertificateName).pfx"

  # Certificate expires after 10 years.
  $cert = New-SelfSignedCertificate `
    -Subject "CN=$CertificateName" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(10)

  Export-Certificate `
    -Cert $cert `
    -FilePath $cerPath

  $generatedPassword = (Get-RandomPassword -Length 16)
  $mypwd = ConvertTo-SecureString -String $generatedPassword -Force -AsPlainText

  Export-PfxCertificate `
    -Cert $cert `
    -FilePath $pfxPath `
    -Password $mypwd

  # Cleanup local store.
  $certInstore = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -Match $CertificateName } | Select-Object Thumbprint, FriendlyName
  Remove-Item -Path Cert:\CurrentUser\My\$($certInstore.Thumbprint) -DeleteKey

  Write-Host
  Write-Host "Certificate creation finished."
  Write-Host "*** CER path:               $($cerPath)"
  Write-Host "*** PFX path:               $($pfxPath)"
  Write-Host "*** Certificate password:   $($generatedPassword)"
  Write-Host
  Write-Host -ForegroundColor Yellow "Upload your PFX to Azure DevOps secure files and update your pipeline configuration."

  Write-Output @{ 
    certName = "$CertificateName";
    cerPath  = "$cerPath"; 
    pfxPath  = "$pfxPath"; 
    password = "$generatedPassword"
  }
}

function Update-ADO {
  param(
    [Parameter(HelpMessage = "Personal Access Token with read/write permissions to variable groups and secret files.")]
    [string] $PatToken,
    
    [Parameter(HelpMessage = "Full organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $OrganizationUrl,
    
    [Parameter(HelpMessage = "Project name (follows organization name in the URL).")]
    [string] $Project,

    [string] $VariableGroupName,
    
    # Hashtable in this format: 
    #   @{ "variable1" = @{ value = "val1"; secret = "false" }; "variable2" = @{value = "val2"; secret = "true"}}
    # secret "true"/"false" should be literal string, not boolean, because it's used directly in a command
    [Parameter(HelpMessage = "Hashtable of variables, each containing another hashtable of value and secret (true, false).")]
    [object] $Variables,
    
    # Optional - if not provided, secure file will not be created.
    [string] $SecureFileName = "",
    [string] $SecureFileLocalPath = ""
  )

  $PatToken | az devops login --organization $OrganizationUrl

  $variableGroupId = (az pipelines variable-group list --organization $OrganizationUrl --project $Project | ConvertFrom-Json | Where-Object { $_.Name -eq "$($VariableGroupName)" }).Id

  # Create the variable group if it doesn't exist.
  if ($null -eq $variableGroupId) {
    Write-Host "Creating variable group $VariableGroupName..."
    # New variable group cannot be empty - initializing with temporary variable.
    # The other vars are created in a ForEach loop, because we need both non-secret and secret variables (which cannot be created during `variable-group create/update`).
    $variableGroupId = (az pipelines variable-group create --name "$VariableGroupName" --variables "delete=me" --organization $OrganizationUrl --project $Project | ConvertFrom-Json).Id
  }

  $Variables.Keys | ForEach-Object {
    Write-Host "Creating variable $_ ..."
    az pipelines variable-group variable create --organization $OrganizationUrl --project $Project --group-id $variableGroupId --name $_ --value "$($Variables[$_].value)" --secret "$($Variables[$_].secret)"

    if ($LASTEXITCODE -eq 1) {
      # Creation failed, the variable might exist - let's try update
      Write-Host "Creation failed. Trying update of existing variable..."
      az pipelines variable-group variable update --organization $OrganizationUrl --project $Project --group-id $variableGroupId --name $_ --value "$($Variables[$_].value)" --secret "$($Variables[$_].secret)"
    }
  }

  # Attempt to remove the temporary variable - should produce non-blocking error if it doesn't exist.
  #Write-Host "Trying to remove the temporary variable. Error is expected if it's not present..."
  #(az pipelines variable-group variable delete --group-id $variableGroupId --name "delete" --organization $OrganizationUrl --project $Project -y)
  Write-Host "Trying to remove the temporary variable. Error is expected if it's not present..."
  $currentVars = az pipelines variable-group variable list --group-id $variableGroupId --organization $OrganizationUrl --project $Project | ConvertFrom-Json -AsHashtable
  
  if ($currentVars.ContainsKey("delete")) {
    Write-Host "Removing the temporary variable..."
    az pipelines variable-group variable delete --group-id $variableGroupId --name "delete" --organization $OrganizationUrl --project $Project -y
  }
  else {
    Write-Host "Temporary variable not found, skipping removal."
  }

  if (($SecureFileName -eq "") -or ($SecureFileLocalPath -eq "")) {
    Write-Host "SecureFileName or SecureFileLocalPath not provided, skipping upload."
  }
  else {
    Write-Host "Uploading secure file $SecureFileName..."
    # Uploading secure files other than text is not supported through Azure CLI (https://github.com/Azure/azure-devops-cli-extension/issues/1010) - the REST endpoint has to be used.
    #
    # Based on: https://github.com/microsoft/azure-pipelines-tasks/issues/9172
    $secureFilesBaseUri = "$OrganizationUrl/$Project/_apis/distributedtask/securefiles"
    $uploadSecureFileUri = "$($secureFilesBaseUri)?api-version=5.0-preview.1&name=$SecureFileName"
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $PatToken)))
    $headers = @{
      Authorization = ("Basic {0}" -f $base64AuthInfo)
    }

    try {
      Invoke-RestMethod -Uri $uploadSecureFileUri -Method Post -ContentType "application/octet-stream" -Headers $headers -InFile "$SecureFileLocalPath"
    }
    catch {
      Write-Host "Error when creating new secure file, there's a chance it already exists."
      
      # Get existing secure file ID from the list of all files
      $secureFiles = (Invoke-RestMethod -Uri "$($secureFilesBaseUri)?api-version=5.0-preview.1" -Method Get -ContentType "application/octet-stream" -Headers $headers)
      $secureFileId = ($secureFiles.value | Where-Object { $_.name -eq "$SecureFileName" }).id
      $secureFileId

      Write-Host "Deleting the file..."
      Invoke-RestMethod -Uri "$($secureFilesBaseUri)/$($secureFileId)?api-version=5.0-preview.1" -Method Delete -ContentType "application/octet-stream" -Headers $headers

      Write-Host "Uploading again..."
      Invoke-RestMethod -Uri $uploadSecureFileUri -Method Post -ContentType "application/octet-stream" -Headers $headers -InFile "$SecureFileLocalPath"
    }
  }
}

# Based on: https://devblogs.microsoft.com/scripting/generating-a-new-password-with-windows-powershell/
function Get-RandomPassword {
  param(
    [int] $Length
  )

  # Selection of PowerShell-safe characters for the password.
  $ascii = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".ToCharArray()

  # Alternatively, this snippet can be used to generate the full list automatically.
  # $ascii = $null;
  # for ($a = 48; $a –le 122; $a++) { 
  #   $ascii += , [char][byte]$a 
  # }

  for ($loop = 1; $loop -le $length; $loop++) {
    $TempPassword += ($ascii | Get-Random)
  }

  return $TempPassword
}