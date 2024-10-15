param (
    [Parameter()]
    [string] $ResourceGroupApim,
    [Parameter()]
    [string] $ApimServiceName,
    [Parameter()]
    [string] $ProductName = "unlimited"
)

az apim product list -n $ApimServiceName `
    -g $ResourceGroupApim -o table

# get product id from product name
$ProductID = az apim product list -n $ApimServiceName `
    -g $ResourceGroupApim --query "[?name=='$ProductName'].id" -o tsv

Write-Host "Product ID: $ProductID"

# az apim product show --product-id $ProductID `
#     --resource-group $ResourceGroupApim `
#     --service-name $ApimServiceName

az apim product delete --product-id $ProductID `
    --resource-group $ResourceGroupApim `
    --service-name $ApimServiceName `
    --delete-subscriptions true
