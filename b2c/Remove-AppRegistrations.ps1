#$AppName = "Frontend application dev"
$TenantId = "fe666dc0-dcc0-485c-a421-06066f86713a"

az account clear
az login --tenant $TenantId --allow-no-subscriptions

$appNames = @("Frontend application dev", "Frontend application prd", "Backend application dev", "Backend application prd", "Frontend App for APIM Dev Portal dev", "Frontend App for APIM Dev Portal prd")
foreach ($AppName in $appNames) { 

    Write-Host "delete exisiting app registrations by the same name $AppName (if they exist)"
    $currentAppRegs = az ad app list --display-name $AppName
    $currentAppRegsObject = $currentAppRegs | ConvertFrom-Json
    $currentAppRegsObject | ForEach-Object -Process {
        if ($_.displayName -eq $AppName) {
            Write-Host found previous app reg  $_.DisplayName with appId $_.appId
            Write-Host so will delete it
            az ad app delete --id $_.appId
        }
    }
}