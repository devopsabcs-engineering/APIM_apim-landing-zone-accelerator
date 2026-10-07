BeforeAll {
    . (Join-Path $PSScriptRoot '../Get-Apim007ReleaseState.ps1')
    . (Join-Path $PSScriptRoot '../Set-Apim007ReleaseState.ps1')
    $script:ShaA = 'a' * 64
    $script:ShaB = 'b' * 64
    $script:Source = 'c' * 40
    $script:Now = [datetime]::new(2026, 10, 6, 12, 0, 0, [DateTimeKind]::Utc)

    function New-TestState {
        param([string]$Status, [string]$Tag = 'apim007-candidate-1-aaaaaaa', [string]$Sha = $script:ShaA, [string]$RunId = '100', [object[]]$History = @())
        $json = [ordered]@{ candidateTag = $Tag; candidateSha256 = $Sha; sourceSha = $script:Source; runId = $RunId; status = $Status; updatedUtc = '2026-10-06T11:00:00Z'; history = $History } |
            ConvertTo-Json -Depth 5 -Compress
        return ConvertFrom-Apim007ReleaseStateValue -Value $json
    }
}

Describe 'Release state value' {
    It 'round-trips through serialize and parse' {
        $json = New-Apim007ReleaseStateValue -Status clean -CandidateTag 'apim007-candidate-1-aaaaaaa' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '100' -NowUtc $script:Now
        $state = ConvertFrom-Apim007ReleaseStateValue -Value $json
        $state.status | Should -Be 'clean'
        $state.candidateSha256 | Should -Be $script:ShaA
        $state.updatedUtc | Should -Be '2026-10-06T12:00:00Z'
        @($state.history).Count | Should -Be 1
        $state.history[0].cleanUtc | Should -Be '2026-10-06T12:00:00Z'
    }

    It 'keeps at most 10 history entries de-duplicated by tag' {
        $current = $null
        foreach ($i in 1..12) {
            $json = New-Apim007ReleaseStateValue -Current $current -Status clean -CandidateTag "tag-$i" -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId "$i" -NowUtc $script:Now
            $current = $json | ConvertFrom-Json -AsHashtable
        }
        $json = New-Apim007ReleaseStateValue -Current $current -Status clean -CandidateTag 'tag-5' -CandidateSha256 $script:ShaB -SourceSha $script:Source -RunId '13' -NowUtc $script:Now
        $state = ConvertFrom-Apim007ReleaseStateValue -Value $json
        @($state.history).Count | Should -Be 10
        @($state.history | Where-Object candidateTag -EQ 'tag-5').Count | Should -Be 1
        $state.history[0].candidateTag | Should -Be 'tag-5'
        $state.history[0].candidateSha256 | Should -Be $script:ShaB
    }

    It 'keeps the dirty attempt candidate when none is supplied' {
        $current = (New-Apim007ReleaseStateValue -Status deploying -CandidateTag 'tag-9' -CandidateSha256 $script:ShaB -SourceSha $script:Source -RunId '200' -NowUtc $script:Now) | ConvertFrom-Json -AsHashtable
        $state = ConvertFrom-Apim007ReleaseStateValue -Value (New-Apim007ReleaseStateValue -Current $current -Status dirty -RunId '200' -NowUtc $script:Now)
        $state.status | Should -Be 'dirty'
        $state.candidateTag | Should -Be 'tag-9'
    }

    It 'enforces the 4096-character named-value limit' {
        $current = @{ history = @(foreach ($i in 1..10) { @{ candidateTag = ('t' * 220) + $i; candidateSha256 = $script:ShaA; sourceSha = $script:Source; cleanUtc = '2026-10-06T00:00:00Z' } }) }
        { New-Apim007ReleaseStateValue -Current $current -Status clean -CandidateTag ('n' * 128) -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '1' -NowUtc $script:Now } |
            Should -Throw '*named-value limit*'
    }

    It 'rejects invalid fields' {
        { New-Apim007ReleaseStateValue -Status clean -CandidateTag 'tag' -CandidateSha256 'xyz' -SourceSha $script:Source -RunId '1' } | Should -Throw '*CandidateSha256*'
    }
}

Describe 'Release gate' {
    It 'allows a fresh target' {
        (Resolve-Apim007ReleaseGate -State $null -Environment prod -CandidateTag 't' -CandidateSha256 $script:ShaA).Allowed | Should -BeTrue
    }

    It 'blocks while the owner run is in progress' {
        Mock Invoke-Gh { '{"status":"in_progress"}' }
        $gate = Resolve-Apim007ReleaseGate -State (New-TestState -Status deploying -RunId '100') -Environment dev -CandidateTag 't' -CandidateSha256 $script:ShaA -CurrentRunId '300'
        $gate.Allowed | Should -BeFalse
        $gate.Reason | Should -Match 'being deployed by run 100'
    }

    It 'converts a stale deploying state to dirty and lets dev proceed' {
        Mock Invoke-Gh { '{"status":"completed"}' }
        $gate = Resolve-Apim007ReleaseGate -State (New-TestState -Status deploying -RunId '100') -Environment dev -CandidateTag 'other' -CandidateSha256 $script:ShaB -CurrentRunId '300'
        $gate.Allowed | Should -BeTrue
        $gate.EffectiveStatus | Should -Be 'dirty'
        $gate.ConvertedToDirty | Should -BeTrue
        Should -Invoke Invoke-Gh -Times 1 -Exactly -ParameterFilter { $Arguments -contains '100' -and $Arguments -contains 'status' }
    }

    It 'treats a deploying state owned by this run as dirty without calling gh' {
        Mock Invoke-Gh { throw 'should not be called' }
        $gate = Resolve-Apim007ReleaseGate -State (New-TestState -Status deploying -RunId '300') -Environment dev -CandidateTag 't' -CandidateSha256 $script:ShaA -CurrentRunId '300'
        $gate.EffectiveStatus | Should -Be 'dirty'
        Should -Invoke Invoke-Gh -Times 0 -Exactly
    }

    It 'blocks when the owner run status cannot be resolved' {
        Mock Invoke-Gh { throw 'gh failed' }
        (Resolve-Apim007ReleaseGate -State (New-TestState -Status deploying -RunId '100') -Environment dev -CurrentRunId '300').Allowed | Should -BeFalse
    }

    It 'blocks forward promotion to a dirty prod' {
        $gate = Resolve-Apim007ReleaseGate -State (New-TestState -Status dirty -Tag 'tag-1' -Sha $script:ShaA) -Environment prod -CandidateTag 'tag-2' -CandidateSha256 $script:ShaB
        $gate.Allowed | Should -BeFalse
        $gate.Reason | Should -Match 'prod is dirty'
    }

    It 'allows a retry of the dirty prod candidate' {
        (Resolve-Apim007ReleaseGate -State (New-TestState -Status dirty -Tag 'tag-1' -Sha $script:ShaA) -Environment prod -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA).Allowed | Should -BeTrue
    }

    It 'allows a rollback to a prod history entry while dirty' {
        $history = @(@{ candidateTag = 'tag-0'; candidateSha256 = $script:ShaB; sourceSha = $script:Source; cleanUtc = '2026-10-05T00:00:00Z' })
        $state = New-TestState -Status dirty -Tag 'tag-1' -Sha $script:ShaA -History $history
        (Resolve-Apim007ReleaseGate -State $state -Environment prod -CandidateTag 'tag-0' -CandidateSha256 $script:ShaB -IsRollback).Allowed | Should -BeTrue
    }

    It 'allows a rollback qualified by the dev history' {
        $devState = New-TestState -Status clean -Tag 'tag-2' -History @(@{ candidateTag = 'tag-0'; candidateSha256 = $script:ShaB; sourceSha = $script:Source; cleanUtc = '2026-10-05T00:00:00Z' })
        $prodState = New-TestState -Status clean -Tag 'tag-1'
        (Resolve-Apim007ReleaseGate -State $prodState -Environment prod -CandidateTag 'tag-0' -CandidateSha256 $script:ShaB -IsRollback -AdditionalHistoryState $devState).Allowed | Should -BeTrue
    }

    It 'rejects a rollback tag that is not in any history' {
        $gate = Resolve-Apim007ReleaseGate -State (New-TestState -Status clean) -Environment prod -CandidateTag 'tag-x' -CandidateSha256 $script:ShaB -IsRollback
        $gate.Allowed | Should -BeFalse
        $gate.Reason | Should -Match 'not in a release-state history'
    }

    It 'rejects a rollback whose SHA256 differs from history' {
        $history = @(@{ candidateTag = 'tag-0'; candidateSha256 = $script:ShaB; sourceSha = $script:Source; cleanUtc = '2026-10-05T00:00:00Z' })
        (Resolve-Apim007ReleaseGate -State (New-TestState -Status clean -History $history) -Environment prod -CandidateTag 'tag-0' -CandidateSha256 $script:ShaA -IsRollback).Allowed | Should -BeFalse
    }

    It 'requires dev to be clean on the candidate for plan-prod' {
        $state = New-TestState -Status clean -Tag 'tag-1' -Sha $script:ShaA
        (Resolve-Apim007ReleaseGate -State $state -Environment dev -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -RequireCleanCandidate).Allowed | Should -BeTrue
        (Resolve-Apim007ReleaseGate -State $state -Environment dev -CandidateTag 'tag-2' -CandidateSha256 $script:ShaA -RequireCleanCandidate).Allowed | Should -BeFalse
        (Resolve-Apim007ReleaseGate -State (New-TestState -Status dirty -Tag 'tag-1') -Environment dev -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -RequireCleanCandidate).Allowed | Should -BeFalse
    }
}

Describe 'Release state scripts with mocked az' {
    BeforeEach {
        $script:Written = $null
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'create' -or $Arguments -contains 'update' } -MockWith {
            $valueArgument = $Arguments[[array]::IndexOf($Arguments, '--value') + 1]
            $script:Written = [pscustomobject]@{ Verb = $Arguments[2]; Value = Get-Content -Raw -LiteralPath $valueArgument.Substring(1); Arguments = $Arguments }
            ''
        }
    }

    It 'reports a missing named value as a fresh target' {
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { $null }
        $result = Get-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Environment prod -CandidateTag 't' -CandidateSha256 $script:ShaA -Gate 6>$null
        $result.exists | Should -BeFalse
        $result.gate.Allowed | Should -BeTrue
    }

    It 'throws through -Gate when blocked and writes the output file' {
        $value = (New-Apim007ReleaseStateValue -Status dirty -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '5' -NowUtc $script:Now)
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { @{ name = 'apim007-release-state'; secret = $false; value = $value } | ConvertTo-Json -Compress }
        $output = Join-Path $TestDrive 'prod-state.json'
        { Get-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Environment prod -CandidateTag 'tag-2' -CandidateSha256 $script:ShaB -Gate -OutputPath $output 6>$null } |
            Should -Throw '*Release gate blocked*'
        (Get-Content -Raw $output | ConvertFrom-Json).gate.Allowed | Should -BeFalse
    }

    It 'creates the named value from a file when missing' {
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { $null }
        $result = Set-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Status deploying -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '42' 6>$null
        $result.Changed | Should -BeTrue
        $script:Written.Verb | Should -Be 'create'
        $script:Written.Arguments | Should -Contain '--secret'
        ($script:Written.Value | ConvertFrom-Json).status | Should -Be 'deploying'
    }

    It 'updates to clean and appends history' {
        $value = (New-Apim007ReleaseStateValue -Status deploying -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '42' -NowUtc $script:Now)
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { @{ secret = $false; value = $value } | ConvertTo-Json -Compress }
        $null = Set-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Status clean -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '42' 6>$null
        $script:Written.Verb | Should -Be 'update'
        $written = $script:Written.Value | ConvertFrom-Json
        $written.status | Should -Be 'clean'
        @($written.history).Count | Should -Be 1
    }

    It 'sets dirty only when this run owns a deploying state' {
        $value = (New-Apim007ReleaseStateValue -Status clean -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '41' -NowUtc $script:Now)
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { @{ secret = $false; value = $value } | ConvertTo-Json -Compress }
        $result = Set-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Status dirty -RunId '42' -OnlyIfOwnedDeploying 6>$null
        $result.Changed | Should -BeFalse
        $script:Written | Should -BeNullOrEmpty
    }

    It 'marks an owned deploying state dirty' {
        $value = (New-Apim007ReleaseStateValue -Status deploying -CandidateTag 'tag-1' -CandidateSha256 $script:ShaA -SourceSha $script:Source -RunId '42' -NowUtc $script:Now)
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { @{ secret = $false; value = $value } | ConvertTo-Json -Compress }
        $result = Set-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Status dirty -RunId '42' -OnlyIfOwnedDeploying 6>$null
        $result.Changed | Should -BeTrue
        ($script:Written.Value | ConvertFrom-Json).candidateTag | Should -Be 'tag-1'
    }

    It 'refuses a secret named value' {
        Mock Invoke-Az -ParameterFilter { $Arguments -contains 'show' } -MockWith { '{"secret":true,"value":null}' }
        { Get-Apim007ReleaseStateMain -ResourceGroup rg -ServiceName apim -Environment dev } | Should -Throw '*must not be secret*'
    }
}
