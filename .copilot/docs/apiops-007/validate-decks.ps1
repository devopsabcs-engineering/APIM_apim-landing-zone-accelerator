param([string]$Directory = $PSScriptRoot)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$existingPowerPoint = @(Get-Process POWERPNT -ErrorAction SilentlyContinue).Count -gt 0
$powerPoint = New-Object -ComObject PowerPoint.Application
$results = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($name in @('APIOps-007-English', 'APIOps-007-Francais')) {
        $file = Join-Path $Directory "$name.pptx"
        $renderDirectory = Join-Path $Directory "$name-preview"
        $null = New-Item -ItemType Directory -Force -Path $renderDirectory
        $presentation = $powerPoint.Presentations.Open($file, -1, 0, 0)
        try {
            if ($presentation.Slides.Count -ne 10) { throw "Wrong slide count: $name" }
            $presentation.Export($renderDirectory, 'PNG', 1600, 900)
            foreach ($slide in $presentation.Slides) {
                foreach ($shape in $slide.Shapes) {
                    if ($shape.HasTextFrame -ne -1 -or $shape.TextFrame2.HasText -ne -1) { continue }
                    $frame = $shape.TextFrame2
                    $availableHeight = $shape.Height - $frame.MarginTop - $frame.MarginBottom
                    $availableWidth = $shape.Width - $frame.MarginLeft - $frame.MarginRight
                    if ($frame.TextRange.BoundHeight -gt ($availableHeight + 2) -or
                        $frame.TextRange.BoundWidth -gt ($availableWidth + 2)) {
                        $results.Add([pscustomobject]@{
                            Deck = $name; Slide = $slide.SlideIndex; Text = $frame.TextRange.Text
                            Height = $frame.TextRange.BoundHeight; AvailableHeight = $availableHeight
                            Width = $frame.TextRange.BoundWidth; AvailableWidth = $availableWidth
                        })
                    }
                }
            }
        } finally {
            $presentation.Close()
            $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($presentation)
        }
        $contact = [Drawing.Bitmap]::new(1600, 2250)
        $graphics = [Drawing.Graphics]::FromImage($contact)
        try {
            for ($index = 1; $index -le 10; $index++) {
                $image = [Drawing.Image]::FromFile((Join-Path $renderDirectory "Slide$index.PNG"))
                try {
                    $graphics.DrawImage($image, (($index - 1) % 2) * 800, [Math]::Floor(($index - 1) / 2) * 450, 800, 450)
                } finally { $image.Dispose() }
            }
            $contact.Save((Join-Path $Directory "$name-contact.png"), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $contact.Dispose() }
    }
} finally {
    if (-not $existingPowerPoint -and $powerPoint.Presentations.Count -eq 0) { $powerPoint.Quit() }
    $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint)
}
ConvertTo-Json -InputObject @($results.ToArray()) -Depth 5 | Set-Content (Join-Path $Directory 'text-fit-results.json')
if ($results.Count -gt 0) { $results | Format-Table -Wrap; throw "$($results.Count) text-fit warnings" }
Write-Output 'PASS: 20 slides rendered in PowerPoint; all text fits its bounding box.'
