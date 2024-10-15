param
(
    [Parameter(Mandatory = $true)] [string] $ProjectName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$orgUrl,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$instanceNumber
)
# https://colinsalmcorner.com/az-devops-like-a-boss/#example-8-creating-and-deleting-yml-environments-using-invoke

#We can use az pipelines variable-group commands to manipulate variable groups. Here’s how we list all the variable groups in a Team Project:

az pipelines variable-group list -p $ProjectName --org $orgUrl --query "[].name" -o tsv

#To create a variable group, we use the create subcommand. We can also specify key/value pairs using the --variables arg:
$variableGroupsToCreate = @(
    "APIM_AAD_main_vars_$instanceNumber",
    "APIM_AAD_frontend_dev_vars_$instanceNumber",
    "APIM_AAD_frontend_prd_vars_$instanceNumber"
)
foreach ($varGroupName in $variableGroupsToCreate) {
    az pipelines variable-group create --name $varGroupName -p $ProjectName --org $orgUrl --authorize --variables delete="me" #var2="val2"
}


