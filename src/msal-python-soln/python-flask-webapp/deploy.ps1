param (
    [Parameter()]
    [string] $ResourceGroupName = "rg-msal-python-soln",
    [Parameter()]
    [string] $Location = "canadacentral",
    [Parameter()]
    [string] $Subscription = "ME-MngEnvMCAP675646-emknafo-1",
    [Parameter()]
    [string] $templateFile = "main.bicep",
    [Parameter()]
    [string] $deploymentName = "msal-python-soln-deployment",
    [Parameter()]
    [string] $secretValue
)

# if secret value is not provided, get it from environment variable CLIENT_SECRET_FLASK_APP
if (-not $secretValue) {
    $secretValue = $env:CLIENT_SECRET_FLASK_APP
}
else {
    Write-Host "Secret value provided"
}

az login
az account set --subscription $Subscription
az group create --name $ResourceGroupName `
    --location $Location

# deploy infrastructure
az deployment group create --resource-group "rg-msal-python-soln" `
    --name $deploymentName `
    --template-file $templateFile `
    --parameters secretValue=$secretValue

# get webapp name
$webappName = az deployment group show --resource-group "rg-msal-python-soln" `
    --name $deploymentName --query properties.outputs.webAppName.value -o tsv

# deploy webapp
$deployWebApp = $false
if ($deployWebApp) {
    az webapp up --runtime PYTHON:3.9 `
        --name $webappName --logs `
        --resource-group $ResourceGroupName `
        --location $Location `
        --subscription $Subscription
        
}
else {
    Write-Output "Skipping webapp deployment"
}

