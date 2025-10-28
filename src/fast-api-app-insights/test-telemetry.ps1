#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test Application Insights telemetry by making sample requests.

.DESCRIPTION
    This script makes multiple requests to the FastAPI endpoints to generate
    telemetry data for verification in Application Insights.

.PARAMETER BaseUrl
    The base URL of the FastAPI application. Default: http://localhost:8000

.PARAMETER Requests
    Number of requests to make to each endpoint. Default: 10

.EXAMPLE
    .\test-telemetry.ps1
    Make 10 requests to each endpoint

.EXAMPLE
    .\test-telemetry.ps1 -Requests 20
    Make 20 requests to each endpoint
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://localhost:8000",

    [Parameter(Mandatory = $false)]
    [int]$Requests = 10
)

Write-Host "🧪 Testing Application Insights Telemetry" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor White
Write-Host "Requests per endpoint: $Requests" -ForegroundColor White
Write-Host ""

# Test if server is running
try {
    $healthCheck = Invoke-RestMethod -Uri "$BaseUrl/healthz" -Method Get -TimeoutSec 5
    Write-Host "✓ Server is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Server is not responding at $BaseUrl" -ForegroundColor Red
    Write-Host "   Please start the server first: .\start.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Function to make requests and show progress
function Test-Endpoint {
    param(
        [string]$Endpoint,
        [string]$Description,
        [int]$Count
    )
    
    Write-Host "Testing $Description ($Endpoint)..." -ForegroundColor Cyan
    
    $successCount = 0
    $failureCount = 0
    $totalDuration = 0
    
    for ($i = 1; $i -le $Count; $i++) {
        Write-Progress -Activity "Making requests to $Endpoint" -Status "Request $i of $Count" -PercentComplete (($i / $Count) * 100)
        
        try {
            $startTime = Get-Date
            $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" -Method Get -TimeoutSec 30 -ErrorAction Stop
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            
            $successCount++
            $totalDuration += $duration
            
            if ($i % 5 -eq 0) {
                Write-Host "  ✓ Request $i completed ($($duration.ToString('F0'))ms)" -ForegroundColor Gray
            }
        } catch {
            $failureCount++
            Write-Host "  ✗ Request $i failed: $_" -ForegroundColor Red
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    Write-Progress -Activity "Making requests to $Endpoint" -Completed
    
    $avgDuration = if ($successCount -gt 0) { $totalDuration / $successCount } else { 0 }
    
    Write-Host "  Results: $successCount successful, $failureCount failed" -ForegroundColor White
    Write-Host "  Average duration: $($avgDuration.ToString('F0'))ms" -ForegroundColor White
    Write-Host ""
}

# Test each endpoint
Test-Endpoint -Endpoint "/" -Description "Root endpoint" -Count $Requests
Test-Endpoint -Endpoint "/healthz" -Description "Health check" -Count $Requests
Test-Endpoint -Endpoint "/slow" -Description "Slow endpoint (~800ms)" -Count ($Requests / 2)
Test-Endpoint -Endpoint "/chain" -Description "Chain endpoint" -Count ($Requests / 2)

# Test error endpoint (expect failures)
Write-Host "Testing Error endpoint (/error) - Expecting failures..." -ForegroundColor Cyan
$errorCount = 0
for ($i = 1; $i -le 5; $i++) {
    try {
        Invoke-RestMethod -Uri "$BaseUrl/error" -Method Get -TimeoutSec 10 -ErrorAction Stop
    } catch {
        $errorCount++
    }
}
Write-Host "  Results: $errorCount errors tracked (expected)" -ForegroundColor White
Write-Host ""

Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "✅ Telemetry test complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 2-3 minutes for data to appear in Application Insights" -ForegroundColor White
Write-Host "  2. Check Azure Portal > Application Insights > Performance" -ForegroundColor White
Write-Host "  3. Look for metrics in:" -ForegroundColor White
Write-Host "     - Performance blade (request rate, duration, failures)" -ForegroundColor Gray
Write-Host "     - Live Metrics (real-time stream)" -ForegroundColor Gray
Write-Host "     - Metrics Explorer (custom metrics)" -ForegroundColor Gray
Write-Host "     - Transaction search (individual requests)" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 Custom metric names to search for:" -ForegroundColor Cyan
Write-Host "   - http.server.request.count" -ForegroundColor White
Write-Host "   - http.server.request.duration" -ForegroundColor White
Write-Host "   - http.server.request.failures" -ForegroundColor White
Write-Host ""
