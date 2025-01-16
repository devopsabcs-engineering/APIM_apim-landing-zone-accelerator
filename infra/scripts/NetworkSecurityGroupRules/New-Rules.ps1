# CHANGE THESE 2 VARIABLES
$networkSecurityGroupName = "apimnsgozhql6hx7euqiapim-prd-cc-hol-tcek-01" # "apimnsguwybobeka36eqapim-dev-cc-hol-tcek-01" # "nsg-apim-prod-005-cs4jyj6wprtye" # "nsg-apim-dev-005-3snpbfdd5kffc"
$resourceGroupName = "rg-apim-prd-cc-hol-tcek-01" # "rg-apim-dev-cc-hol-tcek-01" # "rg-apim-vnet-external-prod-005-eu2"  #"rg-apim-vnet-external-dev-005-eu2"

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name $networkSecurityGroupName `
    --name CAREFUL_DEMO_AllowAnyCustom443Outbound `
    --priority 361 `
    --direction Outbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefix VirtualNetwork `
    --source-port-range '*' `
    --destination-address-prefix Internet `
    --destination-port-range 443

# now the opposite rule for inbound traffic
az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name $networkSecurityGroupName `
    --name Client_communication_to_API_Management_https `
    --priority 191 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefix Internet `
    --source-port-range '*' `
    --destination-address-prefix VirtualNetwork `
    --destination-port-range 443

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name $networkSecurityGroupName `
    --name CAREFUL_DEMO_AllowAnyCustom80Outbound `
    --priority 110 `
    --direction Outbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefix VirtualNetwork `
    --source-port-range '*' `
    --destination-address-prefix Internet `
    --destination-port-range 80
