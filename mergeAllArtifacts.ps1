Write-Host "Merging all artifacts..."
Write-Host "Merging artifacts.dev-005.api-team-001..."
./mergeArtifacts.ps1 -mergedFolder "./artifacts.dev-005.merged" `
    -rootFolderToMerge "./artifacts.dev-005.api-team-001" `
    -cleanupFolder $true
Write-Host "Merging artifacts.dev-005.api-team-002..."
./mergeArtifacts.ps1 -mergedFolder "./artifacts.dev-005.merged" `
    -rootFolderToMerge "./artifacts.dev-005.api-team-002" `
    -cleanupFolder $false
    