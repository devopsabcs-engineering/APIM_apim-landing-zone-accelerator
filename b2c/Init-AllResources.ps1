param
(
    [Parameter(Mandatory = $false)] [string] $AdoPAT,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()]$AzureDevOpsOrg,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()]$ProjectName,
    [Parameter(Mandatory = $true)] [string] $instanceNumber
)

# sample call:
# .\Init-AllResources.ps1 -AzureDevOpsOrg "MngEnv019702" -ProjectName "APIM Azure AD B2C" -instanceNumber "012"

if ([string]::IsNullOrWhiteSpace($AdoPAT)) {
    Write-Host "ADO PAT is not set. Trying to get it from environment..."
    $AdoPAT = $Env:ADO_PAT_B2C
    #Write-Host "ADO PAT: $AdoPAT" #CAREFUL: do not show this in production
}
else {
    Write-Host "ADO PAT was passed in as a parameter."
}

.\Init-Environments.ps1 -orgUrl "https://dev.azure.com/$AzureDevOpsOrg" `
    -ProjectName $ProjectName `
    -instanceNumber $instanceNumber

.\Init-VariableGroups.ps1 -orgUrl "https://dev.azure.com/$AzureDevOpsOrg" `
    -ProjectName $ProjectName `
    -instanceNumber $instanceNumber

.\Init-SecureFiles.ps1 -AdoPAT $AdoPAT `
    -AzureDevOpsOrg $AzureDevOpsOrg `
    -AzureDevOpsProjectName $ProjectName `
    -SecureNameFile2Upload "ADO_Graph_Client_$instanceNumber" `
    -SecureNameFilePath2Upload .\dummySecureFile.txt