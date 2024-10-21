param (
    [Parameter()]
    [string] $mergedFolder = "./artifacts.dev-005.merged",
    [Parameter()]
    [string] $rootFolderToMerge = "./artifacts.dev-005.api-team-002",
    [Parameter()]
    [bool] $cleanupFolder = $false
)

# delete folder if exists

if ($cleanupFolder -eq $true -and (Test-Path -Path $mergedFolder)) {
    Write-Host "Cleaning up folder $mergedFolder..."
    Remove-Item -Path $mergedFolder -Recurse
    # create folder
    Write-Host "Creating folder $mergedFolder..."
    New-Item -ItemType Directory -Path $mergedFolder
}

# # copy all files from artifacts.dev-005.api-team-001 to artifacts.dev-005.merged
# Copy-Item -Path "./artifacts.dev-005.api-team-001/*" -Destination $mergedFolder -Recurse

# copy all files from artifacts.dev-005.api-team-002 to artifacts.dev-005.merged
Copy-Item -Path "$rootFolderToMerge/*" -Destination $mergedFolder -Recurse -Force

