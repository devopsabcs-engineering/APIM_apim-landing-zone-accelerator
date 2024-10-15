param
(
    [Parameter(Mandatory = $false)] [string] $AdoPAT,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()]$AzureDevOpsOrg,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()]$AzureDevOpsProjectName,
    [Parameter(Mandatory = $true)] [string] $SecureNameFile2Upload,
    [Parameter(Mandatory = $true)] [string] $SecureNameFilePath2Upload
)

# sample call:
# .\Init-SecureFiles.ps1 -AzureDevOpsOrg "MngEnv019702" -AzureDevOpsProjectID "APIM Azure AD B2C" -SecureNameFile2Upload "ADO_Graph_Client_011" -SecureNameFilePath2Upload .\dummySecureFile.txt

try {
    $apiVersion = "6.0-preview"

    if ([string]::IsNullOrWhiteSpace($AdoPAT)) {
        Write-Host "ADO PAT is not set. Trying to get it from environment..."
        $AdoPAT = $Env:ADO_PAT_B2C
        #Write-Host "ADO PAT: $AdoPAT" #CAREFUL: do not show this in production
    }
    else {
        Write-Host "ADO PAT was passed in as a parameter."
    }

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $AdoPAT)))
    $uploadSecureFileURI = "https://dev.azure.com/$AzureDevOpsOrg/$AzureDevOpsProjectName/_apis/distributedtask/securefiles?api-version=$apiVersion&name=$SecureNameFile2Upload"
    $headers = @{
        Authorization = ("Basic {0}" -f $base64AuthInfo)
    }
    Invoke-RestMethod -Uri $uploadSecureFileURI -Method Post -ContentType "application/octet-stream" -Headers $headers -InFile "$SecureNameFilePath2Upload"
}
catch {
    write-host -f Red "Error upload client certificate file [$SecureNameFilePath2Upload] to AzureDevOps secure file!" $_.Exception.Message
    throw "Error occors -> $_.Exception.Message"
}
