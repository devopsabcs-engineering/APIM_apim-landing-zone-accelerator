#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify Application Insights request telemetry is being sent correctly.

.DESCRIPTION
    Makes test requests and checks that the data appears in Application Insights.
    This script helps verify that request rate, duration, and failure metrics are working.
#>

param(
    [int]$Requests = 20
)

Write-Host "🔍 Verifying Application Insights Request Telemetry" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Gray
Write-Host ""

# Check if server is running
try {
    $null = Invoke-RestMethod -Uri "http://localhost:8000/healthz" -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Server is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Server not running. Start with: .\start.ps1" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📊 Generating test traffic for Application Insights..." -ForegroundColor Yellow
Write-Host "   This will help verify the Performance blade metrics:" -ForegroundColor Gray
Write-Host "   • Request Rate (requests/second)" -ForegroundColor Gray
Write-Host "   • Request Duration (average response time)" -ForegroundColor Gray
Write-Host "   • Request Failure Rate (% of failed requests)" -ForegroundColor Gray
Write-Host ""

$successCount = 0
$failureCount = 0
$totalDuration = 0

# Make successful requests
Write-Host "Making $Requests successful requests..." -ForegroundColor Cyan
for ($i = 1; $i -le $Requests; $i++) {
    try {
        $startTime = Get-Date
        $null = Invoke-RestMethod -Uri "http://localhost:8000/" -Method Get -TimeoutSec 10 -ErrorAction Stop
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $successCount++
        $totalDuration += $duration
        
        if ($i % 5 -eq 0) {
            Write-Host "  Progress: $i/$Requests requests ($($duration.ToString('F0'))ms)" -ForegroundColor Gray
        }
    } catch {
        $failureCount++
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "  ✓ Completed $successCount successful requests" -ForegroundColor Green
Write-Host "  Average duration: $([math]::Round($totalDuration / $successCount, 0))ms" -ForegroundColor Gray
Write-Host ""

# Make some slow requests
Write-Host "Making 5 slow requests (to /slow endpoint)..." -ForegroundColor Cyan
$slowCount = 0
$slowDuration = 0
for ($i = 1; $i -le 5; $i++) {
    try {
        $startTime = Get-Date
        $null = Invoke-RestMethod -Uri "http://localhost:8000/slow" -Method Get -TimeoutSec 30 -ErrorAction Stop
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $slowCount++
        $slowDuration += $duration
        Write-Host "  Slow request $i completed ($($duration.ToString('F0'))ms)" -ForegroundColor Gray
    } catch {
        Write-Host "  Slow request $i failed" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "  ✓ Completed $slowCount slow requests" -ForegroundColor Green
Write-Host "  Average duration: $([math]::Round($slowDuration / $slowCount, 0))ms" -ForegroundColor Gray
Write-Host ""

# Make some error requests
Write-Host "Making 5 error requests (to /error endpoint)..." -ForegroundColor Cyan
$errorCount = 0
for ($i = 1; $i -le 5; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:8000/error" -Method Get -TimeoutSec 10 -ErrorAction Stop
    } catch {
        $errorCount++
        Write-Host "  Error $i tracked (expected failure)" -ForegroundColor Gray
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "  ✓ Tracked $errorCount error requests" -ForegroundColor Green
Write-Host ""

Write-Host "=" * 70 -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Test traffic generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📈 Summary:" -ForegroundColor Cyan
Write-Host "   Successful requests: $successCount" -ForegroundColor White
Write-Host "   Slow requests: $slowCount" -ForegroundColor White
Write-Host "   Failed requests: $errorCount" -ForegroundColor White
Write-Host "   Total requests: $($successCount + $slowCount + $errorCount)" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Wait 2-3 minutes, then check Application Insights:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Performance Blade:" -ForegroundColor Cyan
Write-Host "   • Should show Request Rate: ~$([math]::Round(($successCount + $slowCount + $errorCount) / 60, 2)) req/sec" -ForegroundColor White
Write-Host "   • Should show Request Duration with breakdown:" -ForegroundColor White
Write-Host "     - Fast requests (~100-300ms)" -ForegroundColor Gray
Write-Host "     - Slow requests (~800ms)" -ForegroundColor Gray
Write-Host "   • Should show Request Failure Rate: ~$([math]::Round(($errorCount / ($successCount + $slowCount + $errorCount)) * 100, 1))%" -ForegroundColor White
Write-Host ""
Write-Host "2. Live Metrics:" -ForegroundColor Cyan
Write-Host "   • Should show real-time request data immediately" -ForegroundColor White
Write-Host "   • Look for server requests and outgoing HTTP calls" -ForegroundColor White
Write-Host ""
Write-Host "3. Transaction Search:" -ForegroundColor Cyan
Write-Host "   • Filter by 'requests' to see individual HTTP requests" -ForegroundColor White
Write-Host "   • Each request should have:" -ForegroundColor White
Write-Host "     - Request URL (/, /slow, /error)" -ForegroundColor Gray
Write-Host "     - Response code (200, 500)" -ForegroundColor Gray
Write-Host "     - Duration in milliseconds" -ForegroundColor Gray
Write-Host "     - Dependencies (httpbin.org calls)" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 If data still doesn't appear:" -ForegroundColor Yellow
Write-Host "   1. Check Live Metrics first (real-time, should work immediately)" -ForegroundColor White
Write-Host "   2. Verify connection string in Azure Portal matches .env file" -ForegroundColor White
Write-Host "   3. Check Application Insights resource has data ingestion enabled" -ForegroundColor White
Write-Host "   4. Look for errors in the application console output" -ForegroundColor White
Write-Host ""
