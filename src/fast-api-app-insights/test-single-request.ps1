# Test single request and wait to see telemetry
Write-Host "Sending single request..." -ForegroundColor Cyan

$response = Invoke-WebRequest -Uri "http://localhost:8000/" -UseBasicParsing
Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
Write-Host "Response: $($response.Content)" -ForegroundColor Yellow

Write-Host "`nWaiting 10 seconds for telemetry to flush..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

Write-Host "`nCheck Azure Portal now:" -ForegroundColor Yellow
Write-Host "1. Transaction Search -> Last 30 minutes" -ForegroundColor White
Write-Host "2. Look for event types: Request, Trace, Dependency" -ForegroundColor White
Write-Host "3. Live Metrics should show the request" -ForegroundColor White
