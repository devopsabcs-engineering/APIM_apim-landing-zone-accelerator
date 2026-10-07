# Runs real commands, masks identifiers and renders each transcript as a terminal-style PNG
# with headless Microsoft Edge.
# Usage: ./scripts/screenshots/capture-terminal.ps1 [-Only lab-03-*]
# Shots are defined in terminal-shots.ps1 (same folder). Run from the repository root,
# signed in with az (demo subscription) and gh.
[CmdletBinding()]
param([string]$Only = '*')
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$imgRoot = Join-Path $PSScriptRoot '..\..\docs\assets\img'
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

function ConvertTo-Masked([string]$text) {
    $text = [regex]::Replace($text, '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{8}([0-9a-f]{4})\b', '********-****-****-****-********$1')
    $text = [regex]::Replace($text, '(?i)("?(primaryKey|secondaryKey|api-key|accessToken|instrumentationKey)"?\s*[:=]\s*"?)[^",\s]+', '$1***')
    $text = [regex]::Replace($text, '\^\[\[[0-9;]*m', '')
    return [regex]::Replace($text, '\x1b\[[0-9;]*m', '')
}

function Format-Html([object[]]$lines) {
    $enc = { param($s) [Net.WebUtility]::HtmlEncode($s) }
    $body = foreach ($l in $lines) {
        switch ($l.Kind) {
            'cmd' { "<div><span class=""ps"">PS C:\src\APIM_apim-landing-zone-accelerator&gt;</span> <span class=""cmd"">$(& $enc $l.Text)</span></div>" }
            default { "<div class=""$($l.Kind)"">$(if ($l.Text) { & $enc $l.Text } else { '&nbsp;' })</div>" }
        }
    }
    return @"
<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#0b1020;font:14px/1.5 "Cascadia Mono","Cascadia Code",Consolas,monospace;color:#e6e9f2}
.win{margin:18px;border:1px solid #2a3350;border-radius:10px;overflow:hidden;background:#101830;width:1124px}
.bar{background:#131a2e;padding:8px 14px;color:#9aa4c7;font:13px "Segoe UI",system-ui,sans-serif;display:flex;gap:8px;align-items:center}
.dot{width:11px;height:11px;border-radius:50%;display:inline-block}
.pad{padding:14px 18px;white-space:pre-wrap;word-break:break-all}
.ps{color:#0ea5e9}.cmd{color:#fbbf24}.out{color:#e6e9f2}.dim{color:#7d87aa}.ok{color:#4ade80}.bad{color:#f87171}
</style><div class="win"><div class="bar"><span class="dot" style="background:#ef4444"></span><span class="dot" style="background:#f59e0b"></span><span class="dot" style="background:#16a34a"></span><span style="margin-left:8px">PowerShell 7</span></div><div class="pad">$($body -join '')</div></div>
"@
}

. (Join-Path $PSScriptRoot 'terminal-shots.ps1')
Push-Location $repoRoot
try {
    foreach ($name in ($Shots.Keys | Where-Object { $_ -like $Only } | Sort-Object)) {
        $lines = [System.Collections.Generic.List[object]]::new()
        foreach ($step in $Shots[$name]) {
            if ($step.Contains('Note')) { $lines.Add([pscustomobject]@{ Kind = 'dim'; Text = $step.Note }); continue }
            $lines.Add([pscustomobject]@{ Kind = 'cmd'; Text = $step.Show })
            $raw = (& $step.Run 2>&1 | Out-String -Width 150).TrimEnd()
            $max = if ($step.Contains('MaxLines')) { $step.MaxLines } else { 26 }
            $outLines = @((ConvertTo-Masked $raw) -split "`r?`n")
            if ($outLines.Count -gt $max) { $outLines = @($outLines[0..($max - 1)]) + "… ($($outLines.Count - $max) more lines)" }
            foreach ($o in $outLines) {
                $kind = if ($step.Contains('Highlight') -and $o -match $step.Highlight) { 'ok' } elseif ($step.Contains('Bad') -and $o -match $step.Bad) { 'bad' } else { 'out' }
                $lines.Add([pscustomobject]@{ Kind = $kind; Text = $o })
            }
        }
        $lab = ($name -split '/')[0]
        $dir = Join-Path $imgRoot $lab
        $null = New-Item -ItemType Directory -Force -Path $dir
        $html = Join-Path $env:TEMP "term-$($name -replace '/', '-').html"
        [IO.File]::WriteAllText($html, (Format-Html $lines), [Text.UTF8Encoding]::new($false))
        $wrapped = ($lines | ForEach-Object { $len = ([string]$_.Text).Length + $(if ($_.Kind -eq 'cmd') { 42 } else { 0 }); [math]::Max(1, [math]::Ceiling($len / 112)) } | Measure-Object -Sum).Sum
        $height = [int](36 + 28 + 36 + ($wrapped + 1) * 21)
        $png = (Join-Path (Resolve-Path $dir) (($name -split '/')[1] + '.png'))
        $profile = Join-Path $env:TEMP 'edge-term-profile'
        $edgeArgs = '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
            "--user-data-dir=$profile", "--window-size=1162,$height", '--virtual-time-budget=500', "--screenshot=$png", ('file:///' + $html.Replace('\', '/'))
        # Headless Edge sometimes hangs or exits before its child writes the file; wait for the PNG and retry.
        Remove-Item $png -ErrorAction SilentlyContinue
        foreach ($attempt in 1..3) {
            $proc = Start-Process -FilePath $edge -NoNewWindow -PassThru -ArgumentList $edgeArgs
            $deadline = (Get-Date).AddSeconds(60)
            while (-not (Test-Path $png) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
            Start-Sleep -Milliseconds 500
            Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object CommandLine -match 'edge-term-profile' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            if (Test-Path $png) { break }
        }
        if (-not (Test-Path $png)) { throw "Screenshot not written: $png" }
        Remove-Item $html -ErrorAction SilentlyContinue
        Write-Output "ok $name ($($lines.Count) lines)"
    }
}
finally { Pop-Location }
