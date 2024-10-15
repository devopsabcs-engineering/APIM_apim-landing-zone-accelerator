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
    #[Parameter(HelpMessage = "Hashtable of variables, each containing another hashtable of value and secret (true, false).")]
    #[object] $Variables,
      
    # Optional - if not provided, secure file will not be created.
    #[string] $VaiableFileName = "",
    [string] $VariableFileLocalPath = ""
)

# #sample call
# ./Update-ADOFromJson.ps1 -PatToken *** `
#     -OrganizationUrl "https://dev.azure.com/MngEnv019702" `
#     -Project "APIM Azure AD B2C" `
#     -VariableGroupName "APIM_b2c_frontend_dev_vars_008" `
#     -VariableFileLocalPath "./Output/variables/APIM_b2c_frontend_dev_vars_008.json"

$VariablesJson = Get-Content -Path $VariableFileLocalPath -Raw

Write-Host $VariablesJson

$Variables = ConvertFrom-Json -InputObject $VariablesJson -Depth 10 -AsHashtable

Write-Host $Variables

#Write-Host "Logging in to Azure DevOps..."
  
#$PatToken | az devops login --organization $OrganizationUrl
  
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

Write-Host "Trying to remove the temporary variable. Error is expected if it's not present..."
$currentVars = az pipelines variable-group variable list --group-id $variableGroupId --organization $OrganizationUrl --project $Project | ConvertFrom-Json -AsHashtable

if ($currentVars.ContainsKey("delete")) {
    Write-Host "Removing the temporary variable..."
    az pipelines variable-group variable delete --group-id $variableGroupId --name "delete" --organization $OrganizationUrl --project $Project -y
}
else {
    Write-Host "Temporary variable not found, skipping removal."
}
