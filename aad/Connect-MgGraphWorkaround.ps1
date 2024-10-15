#[CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
function Get-AccessToken {
    param (
        
        [Parameter(Mandatory = $false, HelpMessage = "client id of the app registration")]
        [string] $ClientId,
        # Populate with the App Registration details and Tenant ID

        [string] $ClientSecret,
        [string] $TenantId
    )
    #$GraphScopes = "https://graph.microsoft.com/.default"

    Write-Host "Getting access token for tenant $TenantId through app $ClientId..."

    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $body = "grant_type=client_credentials&client_id=$ClientId&client_secret=$ClientSecret&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default"
    $authUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $response = Invoke-RestMethod $authUri  -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
 
    $token = $response.access_token
 
    # Authenticate to the Microsoft Graph
    #Connect-MgGraph -AccessToken $token

    # Get Context
    #Get-MgContext

    # Get the first 10 users

    # If you want to see debugging output of the command just add "-Debug" to the call.
    #Get-MgUser -Top 10

    return @{
        AccessToken = $token
    }
}