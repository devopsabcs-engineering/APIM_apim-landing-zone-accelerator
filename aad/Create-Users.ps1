# Run in PowerShell with the Microsoft.Graph PowerShell module installed.
# Install-Module Microsoft.Graph


#
# Create test users defined in a JSON file.
# Requires Connect-MgGraph with the right B2C Tenant (see wrapper below).
#
function Import-Users {
  [CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
  param (
    $UsersFilePath = "users.json",
    $TenantName, # AAD tenant name, without '.onmicrosoft.com'
    [string] $managementAccessToken
  )

  $TenantId = "$($TenantName).onmicrosoft.com"

  # Getting the right ApiMaster extension property name for this tenant.
  # It contains AppId (without -) of the b2c-extensions-app for this particular tenant.
  #
  # extension_<extension app ID>_ApiMaster
  #$apiMasterExtensionProp = "extension_$((Get-MgApplication | Where-Object { $_.DisplayName.StartsWith("b2c-extensions-app") }).AppId.Replace('-', ''))_ApiMaster";

  $rawUsers = Get-Content $UsersFilePath
  $rawUsers = $rawUsers.Replace('__APITenantName__', "$TenantName") # replace the placeholder with the actual B2C tenant name
  $usersFromJson = $rawUsers | ConvertFrom-Json
  Write-Host $usersFromJson  

  foreach ($user in $usersFromJson.users) {
    $passwordProfile = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordProfile
    $user | Add-Member -NotePropertyName password -NotePropertyValue (Get-RandomPassword -length 14) # generate a random password
    $passwordProfile.Password = $user.password
    $passwordProfile.ForceChangePasswordNextSignIn = $false
    $passwordProfile.ForceChangePasswordNextSignInWithMfa = $false

    $identity = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphObjectIdentity
    $identity.SignInType = "emailAddress"
    $identity.Issuer = $TenantId
    $identity.IssuerAssignedId = $user.email

    #$extension = @{
    #      $apiMasterExtensionProp = $user.apiMaster
    #}

    $mailNickname = $user.email.Split('@')[0]
    Write-Host $mailNickname
    $userEmail = $user.email
    Write-Host $userEmail
    $userDisplayName = $user.displayName
    Write-Host $userDisplayName

    $createdUser = New-MgUser -DisplayName $userDisplayName `
      -AccountEnabled `
      -UserPrincipalName $userEmail `
      -MailNickname  $mailNickname `
      -PasswordProfile $PasswordProfile
    #-AdditionalProperties $extension | Out-Null

    Write-Host $createdUser

    #PATCH https://graph.microsoft.com/beta/users/{id}
    #Content-type: application/json
    $AttributeName = "ApiMaster"
    $AttributeSetName = "ApiConsumers"

    $userApiMaster = ($user.apiMaster).ToString().ToLower()
    
    $reqBody = @"
  {
    "customSecurityAttributes": {
        "$($AttributeSetName)": {
            "@odata.type": "#Microsoft.DirectoryServices.CustomSecurityAttributeValue",
            "$($AttributeName)": $userApiMaster
        }
    }
}
"@ # no whitespace permitted before the closing sequence

    $userId = $($createdUser.Id)

    Write-Host "Created user $($user.email) with ID $($userId)"

    # Create the attribute using the same method as the Portal.
    Write-Host "Assigning custom attribute $($AttributeName) of set $($AttributeSetName) to value $($user.apiMaster) ..."
    Write-Host $reqBody
    #$managementAccessToken = (Get-MgContext).AccessToken
    Write-Host "CAREFUL: This is the management access token:"
    Write-Host $managementAccessToken
    Invoke-WebRequest -Uri "https://graph.microsoft.com/beta/users/$userId" `
      -Method "PATCH" `
      -Headers @{
      "Authorization" = "Bearer $($managementAccessToken)";
      "Content-Type"  = "application/json"
    } `
      -Body $reqBody

    Write-Host "*** Created user: $($user.email) Password: $($user.password)"
  }

  return $usersFromJson.users | Select-Object email, password # The display name is not needed anywhere later so we filter it out
}

# Source: https://arminreiter.com/2021/07/3-ways-to-generate-passwords-in-powershell/
function Get-RandomPassword {
  param (
    [Parameter(Mandatory)]
    [int] $length
  )

  # The character set to use for the password. We removed > { } : $ [ ] ( ) . ^ - ; / | ? because was causing issues with script execution.

  $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+*=@%_!#'.ToCharArray()
  $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
  $bytes = New-Object byte[]($length)

  $rng.GetBytes($bytes)

  $result = New-Object char[]($length)

  for ($i = 0 ; $i -lt $length ; $i++) {
    $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
  }

  return (-join $result)
}

# Wrapper for Import-Users which can be invoked separately - handles authentication.
function New-Users {
  param (
    $UsersFilePath = "users.json",
    $B2CTenantName # B2C tenant name, without '.onmicrosoft.com'
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"

  # Interactive login, so that we don't have to create a separate service principal and handle secrets.
  # Make sure that the user has administrative permissions.
  Connect-MgGraph -TenantId $B2CTenantId -Scopes "User.ReadWrite.All Application.Read.All"

  return Import-Users `
    -UsersFilePath $UsersFilePath `
    -B2CTenantName $B2CTenantName
}