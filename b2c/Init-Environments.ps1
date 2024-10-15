param
(
    [Parameter(Mandatory = $true)] [string] $ProjectName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$orgUrl,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$instanceNumber,
    [Parameter(Mandatory = $false)] [string] $apiVersion = "6.0-preview"
)

# https://colinsalmcorner.com/az-devops-like-a-boss/#example-8-creating-and-deleting-yml-environments-using-invoke
az devops invoke --area distributedtask --resource environments --route-parameters project=$ProjectName --org $orgUrl -o json

$environmentsToCreate = @(
    "APIM_B2C_tenant_testekb2c$instanceNumber",
    "APIM_B2C_frontend_web_development_rg-poc-apim-b2c-dev-$instanceNumber",
    "APIM_B2C_frontend_web_production_rg-poc-apim-b2c-prd-$instanceNumber", 
    "APIM_B2C_backend_infra_development_rg-poc-apim-b2c-dev-$instanceNumber",
    "APIM_B2C_backend_infra_production_rg-poc-apim-b2c-prd-$instanceNumber",
    "APIM_B2C_backend_app_development_rg-poc-apim-b2c-dev-$instanceNumber",
    "APIM_B2C_backend_app_production_rg-poc-apim-b2c-prd-$instanceNumber"
)
foreach ($env in $environmentsToCreate) {
    $envBody = @{
        name        = $env
        description = "My $env environment"
    }
    $infile = "envbody.json"
    Set-Content -Path $infile -Value ($envBody | ConvertTo-Json)
    az devops invoke `
        --area distributedtask --resource environments `
        --route-parameters project=$ProjectName --org $orgUrl `
        --http-method POST --in-file $infile `
        --api-version $apiVersion
    Remove-Item $infile -Force
}
