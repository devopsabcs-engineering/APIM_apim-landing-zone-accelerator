BeforeAll {
    . (Join-Path $PSScriptRoot 'Apim007TestHelpers.ps1')
    . (Join-Path $PSScriptRoot '../New-Apim007Candidate.ps1')
    . (Join-Path $PSScriptRoot '../Test-Apim007Candidate.ps1')
    $script:SourceSha = 'a' * 40
    $script:WeatherImage = 'acrapimdemo007.azurecr.io/apim007-weather@sha256:' + ('1' * 64)
    $script:SoapImage = 'acrapimdemo007.azurecr.io/apim007-soap@sha256:' + ('2' * 64)

    function New-TestCandidate {
        $repo = New-Apim007TestRepository -Path (Join-Path $TestDrive "repo-$([guid]::NewGuid().ToString('N'))")
        $output = Join-Path $TestDrive "out-$([guid]::NewGuid().ToString('N'))"
        $result = New-Apim007CandidateMain -RepositoryRoot $repo.Root -OutputDirectory $output -SourceSha $script:SourceSha `
            -WeatherImage $script:WeatherImage -SoapImage $script:SoapImage
        return $result
    }

    function New-TestArchive {
        param([string]$Directory, [string]$ArchivePath)
        $entries = [string[]]@(Get-ChildItem -LiteralPath $Directory -Recurse -File | ForEach-Object { [IO.Path]::GetRelativePath($Directory, $_.FullName) -replace '\\', '/' })
        [Array]::Sort($entries, [StringComparer]::Ordinal)
        New-Apim007Archive -SourceDirectory $Directory -Entries $entries -ArchivePath $ArchivePath
        return (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

Describe 'New-Apim007Candidate and Test-Apim007Candidate' {
    It 'creates a candidate that verifies end to end' {
        $candidate = New-TestCandidate
        $candidate.ArchiveSha256 | Should -Match '^[a-f0-9]{64}$'
        $manifest = Get-Content -Raw $candidate.ManifestPath | ConvertFrom-Json
        $manifest.images.weather | Should -Be $script:WeatherImage
        $manifest.apiopsCliVersion | Should -Be '1.0.4'
        @($manifest.files.path) | Should -Contain 'scripts/apim-007/Test-Apim007Candidate.ps1'
        @($manifest.files.path) | Should -Contain 'artifacts.007/apis/software-version/specification.wsdl'
        @($manifest.files.path | Where-Object { $_ -like 'scripts/apim-007/tests/*' }).Count | Should -Be 0
        @($manifest.contracts.PSObject.Properties.Name).Count | Should -Be 2

        $verified = Test-Apim007CandidateMain -ArchivePath $candidate.ArchivePath -ExpectedSha256 $candidate.ArchiveSha256 -ExtractPath (Join-Path $TestDrive 'extract-ok')
        $verified.SourceSha | Should -Be $script:SourceSha
        $verified.SoapImage | Should -Be $script:SoapImage
    }

    It 'orders archive entries ordinally' {
        $candidate = New-TestCandidate
        $names = @(Invoke-Apim007Tar -Arguments @('-tzf', $candidate.ArchivePath) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        $sorted = [string[]]$names.Clone()
        [Array]::Sort($sorted, [StringComparer]::Ordinal)
        ($names -join '|') | Should -BeExactly ($sorted -join '|')
    }

    It 'detects an archive hash mismatch' {
        $candidate = New-TestCandidate
        { Test-Apim007CandidateMain -ArchivePath $candidate.ArchivePath -ExpectedSha256 ('0' * 64) -ExtractPath (Join-Path $TestDrive 'extract-bad') } |
            Should -Throw '*SHA256 mismatch*'
    }

    It 'detects a per-file hash mismatch' {
        $candidate = New-TestCandidate
        $policy = Join-Path $candidate.CandidateDirectory 'artifacts.007/apis/weather/policy.xml'
        Add-Content -Path $policy -Value '<!-- tampered -->'
        $archive = Join-Path $TestDrive 'tampered.tar.gz'
        $hash = New-TestArchive -Directory $candidate.CandidateDirectory -ArchivePath $archive
        { Test-Apim007CandidateMain -ArchivePath $archive -ExpectedSha256 $hash -ExtractPath (Join-Path $TestDrive 'extract-tampered') } |
            Should -Throw "*'artifacts.007/apis/weather/policy.xml' hash mismatch*"
    }

    It 'detects an unlisted file' {
        $candidate = New-TestCandidate
        Set-Content -Path (Join-Path $candidate.CandidateDirectory 'scripts/apim-007/Extra.ps1') -Value '# extra'
        $archive = Join-Path $TestDrive 'extra.tar.gz'
        $hash = New-TestArchive -Directory $candidate.CandidateDirectory -ArchivePath $archive
        { Test-Apim007CandidateMain -ArchivePath $archive -ExpectedSha256 $hash -ExtractPath (Join-Path $TestDrive 'extract-extra') } |
            Should -Throw '*unlisted file*'
    }

    It 'detects a non-digest image reference in the candidate manifest' {
        $candidate = New-TestCandidate
        $manifestPath = Join-Path $candidate.CandidateDirectory 'candidate-manifest.json'
        $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable
        $manifest.images.weather = 'acrapimdemo007.azurecr.io/apim007-weather:latest'
        Write-Apim007TestJson -Path $manifestPath -Value $manifest
        $archive = Join-Path $TestDrive 'tag.tar.gz'
        $hash = New-TestArchive -Directory $candidate.CandidateDirectory -ArchivePath $archive
        { Test-Apim007CandidateMain -ArchivePath $archive -ExpectedSha256 $hash -ExtractPath (Join-Path $TestDrive 'extract-tag') } |
            Should -Throw "*image 'weather' is not a digest-form reference*"
    }

    It 'rejects non-digest image references when freezing' {
        $repo = New-Apim007TestRepository -Path (Join-Path $TestDrive 'repo-tag')
        { New-Apim007CandidateMain -RepositoryRoot $repo.Root -OutputDirectory (Join-Path $TestDrive 'out-tag') -SourceSha $script:SourceSha `
                -WeatherImage 'acrapimdemo007.azurecr.io/apim007-weather:latest' -SoapImage $script:SoapImage } | Should -Throw '*sha256:<digest> form*'
    }

    It 'validates the image reference pattern' -TestCases @(
        @{ Ref = 'acr.azurecr.io/apim007-weather@sha256:' + ('a' * 64); Expected = $true }
        @{ Ref = 'localhost:5000/team/app@sha256:' + ('b' * 64); Expected = $true }
        @{ Ref = 'acr.azurecr.io/apim007-weather:1.0'; Expected = $false }
        @{ Ref = 'ACR.azurecr.io/app@sha256:' + ('a' * 64); Expected = $false }
        @{ Ref = 'acr.azurecr.io/app@sha256:' + ('a' * 63); Expected = $false }
    ) {
        Test-Apim007ImageRef -ImageRef $Ref | Should -Be $Expected
    }

    It 'refuses a non-empty output directory' {
        $repo = New-Apim007TestRepository -Path (Join-Path $TestDrive 'repo-busy')
        $output = Join-Path $TestDrive 'out-busy'
        $null = New-Item -ItemType Directory -Path $output
        Set-Content -Path (Join-Path $output 'existing.txt') -Value 'x'
        { New-Apim007CandidateMain -RepositoryRoot $repo.Root -OutputDirectory $output -SourceSha $script:SourceSha -WeatherImage $script:WeatherImage -SoapImage $script:SoapImage } |
            Should -Throw '*new or empty*'
    }
}
