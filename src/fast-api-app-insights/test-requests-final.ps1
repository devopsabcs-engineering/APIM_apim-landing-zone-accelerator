#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Final comprehensive test for Application Insights request telemetry.
#>

Write-Host "`n🔍 Application Insights Request Telemetry Test" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Gray
Write-Host ""

# Test server
Write-Host "1. Testing server connection..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/healthz" -Method Get -ErrorAction Stop
    Write-Host "   ✓ Server is running" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Server not responding" -ForegroundColor Red
    Write-Host "   Start with: Start-Process pwsh -ArgumentList '-File', '.\start.ps1'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "2. Generating diverse request patterns..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$failureCount = 0

# Normal requests
Write-Host "   → 10 fast requests to /" -ForegroundColor Gray
for ($i = 1; $i -le 10; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:8000/" -ErrorAction Stop
        $successCount++
    } catch { $failureCount++ }
    Start-Sleep -Milliseconds 200
}

# Slow requests
Write-Host "   → 3 slow requests to /slow (~800ms each)" -ForegroundColor Gray
for ($i = 1; $i -le 3; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:8000/slow" -ErrorAction Stop
        $successCount++
    } catch { $failureCount++ }
    Start-Sleep -Milliseconds 300
}

# Chain requests
Write-Host "   → 3 chain requests to /chain" -ForegroundColor Gray
for ($i = 1; $i -le 3; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:8000/chain" -ErrorAction Stop
        $successCount++
    } catch { $failureCount++ }
    Start-Sleep -Milliseconds 300
}

# Error requests
Write-Host "   → 4 error requests to /error (expect 500)" -ForegroundColor Gray
for ($i = 1; $i -le 4; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:8000/error" -ErrorAction Stop
    } catch {
        $failureCount++
    }
    Start-Sleep -Milliseconds 200
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Test Complete!" -ForegroundColor Green
Write-Host "   • Successful requests: $successCount" -ForegroundColor White
Write-Host "   • Failed requests: $failureCount" -ForegroundColor White
Write-Host "   • Total requests: $($successCount + $failureCount)" -ForegroundColor White
Write-Host ""
Write-Host "📊 Check Application Insights in Azure Portal:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   IMMEDIATELY (Real-time):" -ForegroundColor Yellow
Write-Host "   1. Go to: Application Insights → Live Metrics" -ForegroundColor White
Write-Host "      • Look for 'Incoming Requests' counter" -ForegroundColor Gray
Write-Host "      • Look for 'Request Rate' and 'Request Duration' charts" -ForegroundColor Gray
Write-Host "      • Should show ~20 total requests" -ForegroundColor Gray
Write-Host ""
Write-Host "   WITHIN 1-2 MINUTES:" -ForegroundColor Yellow
Write-Host "   2. Go to: Application Insights → Transaction search" -ForegroundColor White
Write-Host "      • Filter: Event types → 'Request'" -ForegroundColor Gray
Write-Host "      • Should see individual requests with:" -ForegroundColor Gray
Write-Host "        - URL (/, /slow, /chain, /error)" -ForegroundColor DarkGray
Write-Host "        - Response code (200 or 500)" -ForegroundColor DarkGray
Write-Host "        - Duration in milliseconds" -ForegroundColor DarkGray
Write-Host "        - Dependencies (httpbin.org calls)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   WITHIN 2-3 MINUTES:" -ForegroundColor Yellow
Write-Host "   3. Go to: Application Insights → Performance" -ForegroundColor White
Write-Host "      • Request Rate: Should show activity" -ForegroundColor Gray
Write-Host "      • Request Duration: Average ~500-1000ms" -ForegroundColor Gray
Write-Host "      • Request Failure Rate: ~20% (4 failures / 20 requests)" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 Key Difference:" -ForegroundColor Cyan
Write-Host "   • TRACES = Individual operations/spans (what you saw before)" -ForegroundColor White
Write-Host "   • REQUESTS = HTTP server requests (what Performance blade needs)" -ForegroundColor White
Write-Host "   • We fixed the instrumentation to generate REQUESTS, not just traces" -ForegroundColor White
Write-Host ""
Write-Host "🔧 If still no REQUESTS in Transaction Search:" -ForegroundColor Yellow
Write-Host "   1. Check the PowerShell window running the server for errors" -ForegroundColor White
Write-Host "   2. Verify logs show: 'FastAPI application instrumented successfully'" -ForegroundColor White
Write-Host "   3. Check firewall isn't blocking *.applicationinsights.azure.com" -ForegroundColor White
Write-Host ""
