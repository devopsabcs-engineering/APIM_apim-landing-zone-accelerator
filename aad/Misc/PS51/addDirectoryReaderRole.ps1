#runs on Powershell 5.1

$TenantId = "apiMngEnv019702v002.onmicrosoft.com" #your tenant name

$spName = "aad-extensions-app"

$roleNamesToAssign = @("Directory Readers") #"Application Administrator", 

#Install the Azure AD Module via Install-Module AzureAD [1]
Import-Module AzureAD

#Connect to the Azure Active Directory

Connect-AzureAD -TenantId $TenantId
#az login

foreach ($roleNameToAssign in $roleNamesToAssign) {
    #Get the Id of the "Directory Readers" role

    $roleId = (Get-AzureADDirectoryRole | where-object { $_.DisplayName -eq $roleNameToAssign }).Objectid
    #Get the Service Principal Object ID

    $spObjectId = (Get-AzureADServicePrincipal -SearchString "$spName").ObjectId
    #This of course only works if the result includes only one ObjectId
    #This is not the ObjectId of the application registered in the Azure Active Directory
    #Add service principal to the "Directory Readers" role

    Add-AzureADDirectoryRoleMember -ObjectId $roleId -RefObjectId $spObjectId
    #Check if SP is assigned to the Directory Readers role

    Get-AzureADDirectoryRoleMember -ObjectId $roleId | Where-Object { $_.ObjectId -eq $spObjectId }
    #If you want to remove the Service Principal from the role at a later stage

    #Remove-AzureADDirectoryRoleMember -ObjectId $roleId -MemberId $spObjectId
}