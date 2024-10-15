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

#Write-Host "Logging in to GitHub..."

#gh auth login --with-token $PatToken

Write-Host "Creating GitHub Environment $VariableGroupName ..."
gh api --method PUT -H "Accept: application/vnd.github+json" "repos/$OrganizationUrl/$Project/environments/$VariableGroupName"

$Variables.Keys | ForEach-Object {
    if ($_.ToUpper() -ne $_) {
        Write-Host "Variable name $_ will be transformed into snake case"
        $variableName = $_ -csplit '(?=[A-Z])' -ne '' -join '_'
    }
    else {
        Write-Host "Preserving Variable name"
        $variableName = $_
    }    

    Write-Host "Variable name: $variableName"
    $isSecret = $Variables[$_].secret
    if ($isSecret -eq "true") {
        Write-Host "Creating secret $variableName in environment $VariableGroupName..."
        gh secret set $variableName --repo "$OrganizationUrl/$Project" --body "$($Variables[$_].value)" --env $VariableGroupName
    }
    else {
        Write-Host "Creating variable $variableName in environment $VariableGroupName ..."
        gh variable set $variableName --repo "$OrganizationUrl/$Project" --body "$($Variables[$_].value)" --env $VariableGroupName
    }
}

Write-Host "$OrganizationUrl/$Project"
gh secret list --repo "$OrganizationUrl/$Project" --env $VariableGroupName
gh variable list --repo "$OrganizationUrl/$Project" --env $VariableGroupName
