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
  
$variableGroupId = (az pipelines variable-group list --organization $OrganizationUrl --project $Project | ConvertFrom-Json | Where-Object { $_.Name -eq "$($VariableGroupName)" }).Id

Write-Host "Found $VariableGroupName with var group id $variableGroupId"

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

az pipelines variable-group variable update --group-id $variableGroupId `
    --name MSAL_AUTH_REDIRECT_URI `
    --value "$primaryWebEndpoint"

az pipelines variable-group variable update --group-id $variableGroupId `
    --name API_BACKEND `
    --value "${apimGatewayUrl}/$FunctionAppNameInApim/hello"

# # Create the variable group if it doesn't exist.
# if ($null -eq $variableGroupId) {
#     Write-Host "Creating variable group $VariableGroupName..."
#     # New variable group cannot be empty - initializing with temporary variable.
#     # The other vars are created in a ForEach loop, because we need both non-secret and secret variables (which cannot be created during `variable-group create/update`).
#     $variableGroupId = (az pipelines variable-group create --name "$VariableGroupName" --variables "delete=me" --organization $OrganizationUrl --project $Project | ConvertFrom-Json).Id
# }
  
# $Variables.Keys | ForEach-Object {
#     Write-Host "Creating variable $_ ..."
#     az pipelines variable-group variable create --organization $OrganizationUrl --project $Project --group-id $variableGroupId --name $_ --value "$($Variables[$_].value)" --secret "$($Variables[$_].secret)"
  
#     if ($LASTEXITCODE -eq 1) {
#         # Creation failed, the variable might exist - let's try update
#         Write-Host "Creation failed. Trying update of existing variable..."
#         az pipelines variable-group variable update --organization $OrganizationUrl --project $Project --group-id $variableGroupId --name $_ --value "$($Variables[$_].value)" --secret "$($Variables[$_].secret)"
#     }
# }
  
# # Attempt to remove the temporary variable - should produce non-blocking error if it doesn't exist.

# Write-Host "Trying to remove the temporary variable. Error is expected if it's not present..."
# $currentVars = az pipelines variable-group variable list --group-id $variableGroupId --organization $OrganizationUrl --project $Project | ConvertFrom-Json -AsHashtable

# if ($currentVars.ContainsKey("delete")) {
#     Write-Host "Removing the temporary variable..."
#     az pipelines variable-group variable delete --group-id $variableGroupId --name "delete" --organization $OrganizationUrl --project $Project -y
# }
# else {
#     Write-Host "Temporary variable not found, skipping removal."
# }
