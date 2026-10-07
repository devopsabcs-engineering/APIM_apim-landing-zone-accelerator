# Renders deterministic frames of an animated SVG with headless Microsoft Edge and
# optionally assembles them into a GIF with ffmpeg.
# Usage:
#   ./render-frames.ps1 -Svg docs/assets/anim/apiops-flow.svg -Times 3,8 -OutDir .preview
#   ./render-frames.ps1 -Svg docs/assets/anim/apiops-flow.svg -Gif docs/assets/anim/apiops-flow.gif -Duration 14 -Fps 8
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Svg,
    [double[]]$Times,
    [string]$OutDir,
    [string]$Gif,
    [double]$Duration,
    [int]$Fps = 8,
    [int]$GifWidth = 960
)
$ErrorActionPreference = 'Stop'
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge not found.' }
$source = Get-Content -Raw -LiteralPath $Svg
if ($source -notmatch 'viewBox="0 0 (\d+) (\d+)"') { throw 'SVG has no viewBox.' }
$width = [int]$Matches[1]; $height = [int]$Matches[2]
$work = Join-Path ([IO.Path]::GetTempPath()) ("svgframes-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
$profile = Join-Path $work 'edge-profile'

function Get-Frame([double]$t, [string]$png) {
    $inject = "<style>.flow{animation-delay:-${t}s!important;animation-play-state:paused!important}</style>" +
        "<script>document.documentElement.pauseAnimations();document.documentElement.setCurrentTime($t);</script></svg>"
    $frameSvg = Join-Path $work 'frame.svg'
    [IO.File]::WriteAllText($frameSvg, ($source -replace '</svg>\s*$', $inject), [Text.UTF8Encoding]::new($false))
    $uri = 'file:///' + $frameSvg.Replace('\', '/')
    $null = Start-Process -FilePath $edge -Wait -NoNewWindow -ArgumentList '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
        "--user-data-dir=$profile", "--window-size=$width,$height", '--virtual-time-budget=300', "--screenshot=$png", $uri
    if (-not (Test-Path $png)) { throw "Frame at $t s was not rendered." }
}

try {
    if ($Times) {
        $null = New-Item -ItemType Directory -Force -Path $OutDir
        $base = [IO.Path]::GetFileNameWithoutExtension($Svg)
        foreach ($t in $Times) { Get-Frame $t (Join-Path (Resolve-Path $OutDir) "$base-$t.png"); Write-Output "frame $t" }
    }
    if ($Gif) {
        if (-not $Duration) { throw '-Duration is required with -Gif.' }
        $count = [int][math]::Round($Duration * $Fps)
        for ($i = 0; $i -lt $count; $i++) { Get-Frame ([math]::Round($i / $Fps, 3)) (Join-Path $work ('f{0:D4}.png' -f $i)) }
        $palette = Join-Path $work 'palette.png'
        & ffmpeg -loglevel error -y -framerate $Fps -i (Join-Path $work 'f%04d.png') -vf "scale=${GifWidth}:-1:flags=lanczos,palettegen=stats_mode=diff" $palette
        & ffmpeg -loglevel error -y -framerate $Fps -i (Join-Path $work 'f%04d.png') -i $palette -lavfi "scale=${GifWidth}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" -loop 0 $Gif
        Write-Output "gif $Gif ($count frames)"
    }
}
finally { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
