param(
    [Parameter(HelpMessage = "Personal Access Token with read/write permissions to variable groups and secret files.")]
    [string] $PatToken,
    
    [Parameter(HelpMessage = "Full organization name, including https://. Example: https://dev.azure.com/myorg")]
    [string] $OrganizationUrl,
    
    [Parameter(HelpMessage = "Project name (follows organization name in the URL).")]
    [string] $Project,    
    
    # Optional - if not provided, secure file will not be created.
    [string] $SecureFileName = "",
    [string] $SecureFileLocalPath = ""
)

$PatToken | az devops login --organization $OrganizationUrl

if (($SecureFileName -eq "") -or ($SecureFileLocalPath -eq "")) {
    Write-Host "SecureFileName or SecureFileLocalPath not provided, skipping upload."
}
else {
    Write-Host "Uploading secure file $SecureFileName..."
    # Uploading secure files other than text is not supported through Azure CLI (https://github.com/Azure/azure-devops-cli-extension/issues/1010) - the REST endpoint has to be used.
    #
    # Based on: https://github.com/microsoft/azure-pipelines-tasks/issues/9172
    $secureFilesBaseUri = "$OrganizationUrl/$Project/_apis/distributedtask/securefiles"
    $uploadSecureFileUri = "$($secureFilesBaseUri)?api-version=5.0-preview.1&name=$SecureFileName"
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $PatToken)))
    $headers = @{
        Authorization = ("Basic {0}" -f $base64AuthInfo)
    }

    try {
        Invoke-RestMethod -Uri $uploadSecureFileUri -Method Post -ContentType "application/octet-stream" -Headers $headers -InFile "$SecureFileLocalPath"
    }
    catch {
        Write-Host "Error when creating new secure file, there's a chance it already exists."
      
        # Get existing secure file ID from the list of all files
        $secureFiles = (Invoke-RestMethod -Uri "$($secureFilesBaseUri)?api-version=5.0-preview.1" -Method Get -ContentType "application/octet-stream" -Headers $headers)
        $secureFileId = ($secureFiles.value | Where-Object { $_.name -eq "$SecureFileName" }).id
        $secureFileId

        Write-Host "Deleting the file..."
        Invoke-RestMethod -Uri "$($secureFilesBaseUri)/$($secureFileId)?api-version=5.0-preview.1" -Method Delete -ContentType "application/octet-stream" -Headers $headers

        Write-Host "Uploading again..."
        Invoke-RestMethod -Uri $uploadSecureFileUri -Method Post -ContentType "application/octet-stream" -Headers $headers -InFile "$SecureFileLocalPath"
    }
}
