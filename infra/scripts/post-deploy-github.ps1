param(
    [Parameter(HelpMessage = "Personal Access Token with read/write permissions to variable groups and secret files.")]
    [string] $PatToken,
      
    [Parameter(HelpMessage = "Full organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $OrganizationUrl,
      
    [Parameter(HelpMessage = "Project name (follows organization name in the URL).")]
    [string] $Project,
  
    [string] $VariableGroupName,
    
    [Parameter(HelpMessage = "Resource Group Name containing the Azure Function")]
    [string] $ResourceGroupAzureFunction,
    [Parameter(HelpMessage = "Resource Group Name containing the APIM service")]
    [string] $ResourceGroupApim,
    [Parameter(HelpMessage = "FunctionAppNameInApim e.g. func-b2c-008")]
    [string] $FunctionAppNameInApim
)

# #sample call
# ./post-deploy.ps1 -OrganizationUrl "https://dev.azure.com/MngEnv019702" `
#     -Project "APIM Azure AD B2C" `
#     -VariableGroupName "APIM_b2c_frontend_dev_vars_008" `
#     -ResourceGroupAzureFunction "rg-poc-apim-b2c-dev-008" `
#     -ResourceGroupApim "rg-apim-vnet-external-dev-002"

#Write-Host "Logging in to Azure DevOps..."
  
#$PatToken | az devops login --organization $OrganizationUrl
  
#$variableGroupId = (az pipelines variable-group list --organization $OrganizationUrl --project $Project | ConvertFrom-Json | Where-Object { $_.Name -eq "$($VariableGroupName)" }).Id

#Write-Host "Found $VariableGroupName with var group id $variableGroupId"

Write-Host "looking for apim"
$ApimServiceName = az apim list -g $ResourceGroupApim --query "[0].name" | jq -r
Write-Host "found apim $ApimServiceName"
Write-Host  "looking for apim public ip"
$apimPublicIp = az apim show -g $ResourceGroupApim -n $ApimServiceName --query "publicIpAddresses[0]" | jq -r
Write-Host "public ip is $apimPublicIp"
$apimGatewayUrl = az apim show -g $ResourceGroupApim -n $ApimServiceName --query "gatewayUrl" | jq -r
Write-Host "apim gateway url is $apimGatewayUrl"

#az functionapp list -g rg-poc-apim-b2c-dev-008
Write-Host "looking for function app"
$FunctionAppName = az functionapp list -g $ResourceGroupAzureFunction --query "[0].name" | jq -r
Write-Host "found fnapp $FunctionAppName"

#az storage account list -g rg-poc-apim-b2c-dev-008 -o table
Write-Host "looking for web storage account"
$storages = az storage account list -g $ResourceGroupAzureFunction --query "[].name" | ConvertFrom-Json
$WebStorageAccountName = $storages | Where-Object { $_.Contains("stweb") }
$primaryWebEndpoint = az storage account show -g $ResourceGroupAzureFunction -n $WebStorageAccountName --query "primaryEndpoints.web" | jq -r

# az pipelines variable-group variable update --group-id $variableGroupId `
#     --name MSAL_AUTH_REDIRECT_URI `
#     --value "$primaryWebEndpoint"
$variableName = "MSAL_AUTH_REDIRECT_URI"
$variableValue = "$primaryWebEndpoint"
Write-Host "Updating variable $variableName in environment $VariableGroupName..."
gh variable set $variableName --repo "$OrganizationUrl/$Project" --body "$variableValue" --env $VariableGroupName

# az pipelines variable-group variable update --group-id $variableGroupId `
#     --name API_BACKEND `
#     --value "${apimGatewayUrl}/$FunctionAppNameInApim/hello"

$variableName = "API_BACKEND"
$variableValue = "${apimGatewayUrl}/$FunctionAppNameInApim/hello"
Write-Host "Updating variable $variableName in environment $VariableGroupName..."
gh variable set $variableName --repo "$OrganizationUrl/$Project" --body "$variableValue" --env $VariableGroupName

Write-Host "$OrganizationUrl/$Project"
gh secret list --repo "$OrganizationUrl/$Project" --env $VariableGroupName
gh variable list --repo "$OrganizationUrl/$Project" --env $VariableGroupName
