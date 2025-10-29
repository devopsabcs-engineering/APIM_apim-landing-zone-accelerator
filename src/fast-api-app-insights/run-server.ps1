# Run FastAPI server in a new window
$scriptPath = $PSScriptRoot
$venvPath = Join-Path $scriptPath ".venv\Scripts\Activate.ps1"

Start-Process pwsh -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$scriptPath'; & '$venvPath'; python -m uvicorn main:app --host 0.0.0.0 --port 8000"
)

Write-Host "✅ Server started in a new window" -ForegroundColor Green
Write-Host "📊 Open Azure Portal → Application Insights → Live Metrics" -ForegroundColor Cyan
Write-Host "🔗 Test endpoint: http://localhost:8000/" -ForegroundColor Yellow
