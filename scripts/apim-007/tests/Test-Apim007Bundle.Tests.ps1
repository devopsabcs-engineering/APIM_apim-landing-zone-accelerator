BeforeAll {
    . (Join-Path $PSScriptRoot 'Apim007TestHelpers.ps1')
    $script:BundleScript = Join-Path $PSScriptRoot '../Test-Apim007Bundle.ps1'
    . $script:BundleScript
}

Describe 'Test-Apim007Bundle' {
    BeforeEach {
        $script:Repo = New-Apim007TestRepository -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
    }

    It 'passes the clean fixture in Candidate mode' {
        $result = Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath -Mode Candidate 6>$null
        $result.FileCount | Should -Be 11
    }

    It 'passes in Authoring mode when specifications are missing' {
        Remove-Item (Join-Path $script:Repo.BundlePath 'apis/weather/specification.json')
        Remove-Item (Join-Path $script:Repo.BundlePath 'apis/software-version/specification.wsdl')
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath -Mode Authoring 6>$null } | Should -Not -Throw
    }

    It 'fails in Candidate mode when a specification is missing' {
        Remove-Item (Join-Path $script:Repo.BundlePath 'apis/weather/specification.json')
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath -Mode Candidate } | Should -Throw '*Missing expected file: apis/weather/specification.json*'
    }

    It 'fails on an extra file' {
        Set-Content -Path (Join-Path $script:Repo.BundlePath 'apis/weather/extra.json') -Value '{}'
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*Unexpected file: apis/weather/extra.json*'
    }

    It 'fails on a forbidden path' {
        Set-Content -Path (Join-Path $script:Repo.BundlePath 'policy.xml') -Value '<policies />'
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*Forbidden path: policy.xml*'
    }

    It 'fails on a forbidden name in a path' {
        $directory = Join-Path $script:Repo.BundlePath 'namedValues/instrumentationKey'
        $null = New-Item -ItemType Directory -Path $directory
        Set-Content -Path (Join-Path $directory 'namedValueInformation.json') -Value '{"properties":{}}'
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw "*Forbidden name 'instrumentationKey'*"
    }

    It 'fails on a forbidden name referenced in content' {
        $policy = Join-Path $script:Repo.BundlePath 'apis/weather/policy.xml'
        (Get-Content -Raw $policy).Replace('<backend><base /></backend>', '<backend><base /></backend><!-- apimlogger -->') | Set-Content -Path $policy -NoNewline
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw "*Forbidden name 'apimlogger' referenced*"
    }

    It 'fails on a credential pattern' {
        $path = Join-Path $script:Repo.BundlePath 'namedValues/demo-environment/namedValueInformation.json'
        $value = 'Default' + 'EndpointsProtocol=https;Account' + 'Key=abc'
        Set-Content -Path $path -Value ('{"properties":{"displayName":"demo-environment","secret":false,"value":"' + $value + '"}}')
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*Credential pattern (storage account key)*'
    }

    It 'fails on a key-like value' {
        $path = Join-Path $script:Repo.BundlePath 'namedValues/demo-environment/namedValueInformation.json'
        $key = 'Ab1' + ('x' * 20) + 'Yz9' + ('Q' * 12) + '=='
        Set-Content -Path $path -Value ('{"properties":{"displayName":"demo-environment","secret":false,"value":"' + $key + '"}}')
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*key-like value*'
    }

    It 'fails on an unresolved token' {
        $path = Join-Path $script:Repo.BundlePath 'namedValues/demo-environment/namedValueInformation.json'
        Set-Content -Path $path -Value '{"properties":{"displayName":"demo-environment","secret":false,"value":"{#[ENV]#}"}}'
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*unresolved pipeline token*'
    }

    It 'fails when the ownership filter bytes change' {
        Add-Content -Path $script:Repo.FilterPath -Value 'apiReleases: []'
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*Ownership filter SHA256 does not match*'
    }

    It 'fails on a symlink' {
        $link = Join-Path $script:Repo.BundlePath 'apis/weather/link.json'
        try { $null = New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $script:Repo.BundlePath 'apis/weather/apiInformation.json') -ErrorAction Stop }
        catch { Set-ItResult -Skipped -Because 'symbolic links cannot be created on this host'; return }
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*Symlink or reparse point*'
    }

    It 'fails on an unsafe inventory path' {
        $inventory = Get-Content -Raw $script:Repo.InventoryPath | ConvertFrom-Json -AsHashtable
        $inventory.files += '../outside.json'
        Write-Apim007TestJson -Path $script:Repo.InventoryPath -Value $inventory
        { Test-Apim007BundleMain -InventoryPath $script:Repo.InventoryPath } | Should -Throw '*not a safe relative path*'
    }

    It 'exits non-zero when run as a script' {
        Set-Content -Path (Join-Path $script:Repo.BundlePath 'apis/weather/extra.json') -Value '{}'
        $null = & pwsh -NoProfile -NonInteractive -File $script:BundleScript -InventoryPath $script:Repo.InventoryPath 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
