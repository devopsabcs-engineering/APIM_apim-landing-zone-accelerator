# create azure devops yaml environments with rest api
# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments?view=azure-devops-rest-6.0

param (
    [Parameter()]
    [string] $ProjectName = "APIM Azure AD B2C",
    [Parameter()]
    [string] $orgUrl = "https://dev.azure.com/MngEnv019702",
    [Parameter()]
    [string] $instanceNumber = "007"
)

# get pat token from environment variable AZURE_DEVOPS_EXT_PAT 
$patToken = $env:AZURE_DEVOPS_EXT_PAT_MNGENV019702
$patToken | az devops login --organization $orgUrl

$envArray = @("APIM_rg-apim-vnet-external-prod-$instanceNumber-eu2_DESTROY", 
    "APIM_rg-apim-vnet-external-prod-$instanceNumber-eu2", 
    "APIM_rg-apim-vnet-external-dev-$instanceNumber-eu2_DESTROY",
    "APIM_rg-apim-vnet-external-dev-$instanceNumber-eu2")

foreach ($env in $envArray) {

    $envBody = @{
        name        = $env
        description = "My $env environment"
    }
    $infile = "envbody.$env.json"
    Set-Content -Path $infile -Value ($envBody | ConvertTo-Json)
    az devops invoke `
        --area distributedtask --resource environments `
        --route-parameters project=$ProjectName --org $orgUrl `
        --http-method POST --in-file $infile `
        --api-version "6.0-preview"
    Remove-Item $infile -Force
}




