BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Test-Apim007LockfileProvenance.ps1')

    function New-TestLock {
        param([string]$Path, [hashtable]$Packages)
        $lock = @{ name = 'x'; lockfileVersion = 3; packages = @{ '' = @{ name = 'x' } } }
        foreach ($k in $Packages.Keys) { $lock.packages[$k] = $Packages[$k] }
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path
    }

    $script:registryDocs = @{
        'https://registry.example/alpha'          = [pscustomobject]@{ versions = [pscustomobject]@{ '1.0.0' = [pscustomobject]@{ dist = [pscustomobject]@{ integrity = 'sha512-AAA' } } } }
        'https://registry.example/@scope%2fbeta'  = [pscustomobject]@{ versions = [pscustomobject]@{ '2.0.0' = [pscustomobject]@{ dist = [pscustomobject]@{ integrity = 'sha512-BBB' } } } }
    }
}

Describe 'Test-Apim007LockfileProvenance' {
    BeforeEach {
        Mock Invoke-Apim007RegistryGet {
            param($Uri)
            if ($script:registryDocs.ContainsKey($Uri)) { return $script:registryDocs[$Uri] }
            throw "404 $Uri"
        }
        Mock Start-Sleep {}
    }

    It 'passes when every integrity matches the registry' {
        $path = Join-Path $TestDrive 'ok.json'
        New-TestLock -Path $path -Packages @{
            'node_modules/alpha'        = @{ version = '1.0.0'; integrity = 'sha512-AAA'; resolved = 'https://feed/alpha.tgz' }
            'node_modules/@scope/beta'  = @{ version = '2.0.0'; integrity = 'sha512-BBB'; resolved = 'https://feed/beta.tgz' }
        }
        $result = Test-Apim007LockfileProvenance -LockfilePath $path -RegistryUrl 'https://registry.example/' -RetryCount 1
        $result | Should -Match 'verified: 2 packages'
    }

    It 'fails on an integrity mismatch' {
        $path = Join-Path $TestDrive 'bad.json'
        New-TestLock -Path $path -Packages @{ 'node_modules/alpha' = @{ version = '1.0.0'; integrity = 'sha512-ZZZ' } }
        { Test-Apim007LockfileProvenance -LockfilePath $path -RegistryUrl 'https://registry.example/' -RetryCount 1 -ErrorAction SilentlyContinue 2>$null } | Should -Throw '*1 of 1*'
    }

    It 'fails when the version is not published upstream' {
        $path = Join-Path $TestDrive 'missing.json'
        New-TestLock -Path $path -Packages @{ 'node_modules/alpha' = @{ version = '9.9.9'; integrity = 'sha512-AAA' } }
        { Test-Apim007LockfileProvenance -LockfilePath $path -RegistryUrl 'https://registry.example/' -RetryCount 1 -ErrorAction SilentlyContinue 2>$null } | Should -Throw
    }

    It 'fails when metadata is unavailable' {
        $path = Join-Path $TestDrive 'unknown.json'
        New-TestLock -Path $path -Packages @{ 'node_modules/gamma' = @{ version = '1.0.0'; integrity = 'sha512-CCC' } }
        { Test-Apim007LockfileProvenance -LockfilePath $path -RegistryUrl 'https://registry.example/' -RetryCount 2 -ErrorAction SilentlyContinue 2>$null } | Should -Throw
    }

    It 'rejects an entry without integrity' {
        $path = Join-Path $TestDrive 'nointegrity.json'
        New-TestLock -Path $path -Packages @{ 'node_modules/alpha' = @{ version = '1.0.0' } }
        { Test-Apim007LockfileProvenance -LockfilePath $path -RegistryUrl 'https://registry.example/' -RetryCount 1 } | Should -Throw '*no version or integrity*'
    }
}
