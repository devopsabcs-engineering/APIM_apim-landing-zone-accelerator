function New-AadIdentityProviderApp {
    param (        
        [string] $ApimServiceName,
        [string] $TenantName,
        [switch] $SkipConnectMgGraph
    )

    # sample call after sourcing the script
    #. .\Create-AadIdentityProvider.ps1
    #New-AadIdentityProviderApp -ApimServiceName apim-257jlvys5ho6o -AadTenantName mngenv019702.com
    if ($SkipConnectMgGraph -eq $false) {
        Connect-MgGraph -TenantId "$TenantName" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"
    }
    else {
        Write-Host "Skipping Connect-MgGraph"
    }
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
    $feApp.DisplayName = "$ApimServiceName-multi-tenant-spa-idp"
    $feApp.SignInAudience = "AzureADMultipleOrgs"
    $feApp.Spa.RedirectUris = "https://$ApimServiceName.developer.azure-api.net/signin" # developer portal url
    $feApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
    $feApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $true
    #$feApp.IsFallbackPublicClient = $true
    #$feApp.Api.Oauth2PermissionScopes = @($apisAccessScope, $apisAccessScope2)
  
    Write-Host "Creating aad identity provider application $($feApp.DisplayName)..."
    $feApp = New-MgApplication -BodyParameter $feApp
    Write-Host "Successfully created aad identity provider app $($feApp.DisplayName) with applicationId $($feApp.AppId)"
  
    # # Adding Apis.Access API permission
    # $apisRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    # $apisRRA.ResourceAccess = @{ Id = $apisAccessScope.Id; Type = "Scope" }
    # $apisRRA.ResourceAppId = $feApp.AppId # ID of the resource that application requires access to - it's the same in our case
  
    # Adding Hello API permission
    # $apisRRAHello = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    # $apisRRAHello.ResourceAccess = @{ Id = $BackendHelloScopeId; Type = "Scope" }
    # $apisRRAHello.ResourceAppId = $BackendAppAppId # ID of the resource that application requires access to - it's the same in our case
  
    # Well-known ID for offline_access = 7427e0e9-2fba-42fe-b0c0-848c9e6a8182
    $userReadScope = @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope" }
  
    # Well-known ID for openid = 37f7f235-527c-4136-accd-4a02d197296e
    $directoryReadAllRole = @{ Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; Type = "Role" }
  
    # offline_access and openid scopes are tied to the same app
    $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    $graphRRA.ResourceAccess = @($userReadScope, $directoryReadAllRole)
    $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants
  
    $resourceAccessList = @(    
        #$apisRRAHello
        $graphRRA
    )
  
    # Update Frontend app with the API permission and identifier URI.
    # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
    Write-Host "Assigning graph permissions for the aad identity provider application $($feApp.DisplayName)..."
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
    $secret.DisplayName = "aad identity provider client secret $($feApp.DisplayName)"
  
    Write-Host "Creating secret for the aad identity provider application $($feApp.DisplayName)..."
    $secret = Add-MgApplicationPassword -ApplicationId $feApp.Id -PasswordCredential $secret
  
    
  
    # also consent for graph
    # need to connect to newly create b2c tenant to grab service principal id aka object id for 'Microsoft Graph'
    #az login --scope https://management.core.windows.net//.default --tenant "$B2CTenantName.onmicrosoft.com" --allow-no-subscriptions
    #$GraphAggregatorServiceServicePrincipalId = az ad sp list --filter "displayname eq 'Microsoft Graph'" --query '[0].id'
    #$GraphAggregatorServiceServicePrincipalId = "ea585e79-8454-429b-8343-0739a4ddc8d3"
    $GraphAggregatorServiceServicePrincipalId = (Get-MgServicePrincipal | Where-Object { $_.DisplayName -match "Microsoft Graph" } | Where-Object { $_.AppId -match "00000003-0000-0000-c000-000000000000" }).Id
    Write-Host "Graph Aggregator Service Service Principal ID: $GraphAggregatorServiceServicePrincipalId"  
    Write-Host "Updating admin consent for the aad identity provider app $($feApp.DisplayName) (graph perms)..."
    New-MgOauth2PermissionGrant `
        -ConsentType AllPrincipals `
        -ClientId $servicePrincipal.Id `
        -Scope "User.Read" `
        -ResourceId $GraphAggregatorServiceServicePrincipalId | Out-Null

    # # Admin Consent - for the Frontend app this is OAuth2 Permission Grant
    #https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/grant-admin-consent?pivots=ms-powershell#grant-admin-consent-for-application-permissions
    Write-Host "Updating admin consent for the aad id provider app $($feApp.DisplayName) (application perms)..."
    #Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -Property AppRoles | Select-Object -ExpandProperty appRoles | Format-List
    $principalId = "$($servicePrincipal.Id)" 
    Write-Host "principalId: $principalId"
    $params = @{
        "ResourceId"  = $GraphAggregatorServiceServicePrincipalId  # ms graph enterprise app
        "PrincipalId" = $principalId
        "AppRoleId"   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # directory read all (app permissions)
    }
          
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId "$($servicePrincipal.Id)" -BodyParameter $params | 
    Format-List Id, AppRoleId, CreatedDateTime, PrincipalDisplayName, PrincipalId, PrincipalType, ResourceDisplayName
      
    #-Scope $apisAccessScope.Value $apisAccessScope2.Value `
  
    Write-Host "*** Azure AD Identity Provider Application '$($feApp.DisplayName)' created."
    Write-Host "*** Client ID: $($feApp.AppId)"
    Write-Host "*** Client Secret: $($secret.SecretText)"
  
    return @{
        ClientID     = $feApp.AppId
        ClientSecret = $secret.SecretText
        DisplayName  = $feApp.DisplayName
    }
}
  