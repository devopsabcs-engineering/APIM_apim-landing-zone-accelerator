# delete folder if exists
$mergedFolder = "./artifacts-dev-005.merged"
if (Test-Path -Path $mergedFolder) {
    Remove-Item -Path $mergedFolder -Recurse
}

# create folder
New-Item -ItemType Directory -Path $mergedFolder

# copy all files from artifacts-dev-005.api-team-001 to artifacts-dev-005.merged
Copy-Item -Path "./artifacts-dev-005.api-team-001/*" -Destination $mergedFolder -Recurse

# copy all files from artifacts-dev-005.api-team-002 to artifacts-dev-005.merged
Copy-Item -Path "./artifacts-dev-005.api-team-002/*" -Destination $mergedFolder -Recurse -Force

