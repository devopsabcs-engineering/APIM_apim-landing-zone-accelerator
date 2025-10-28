#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnose Application Insights telemetry configuration and data flow.

.DESCRIPTION
    This script checks the configuration, makes test requests, and provides
    guidance on troubleshooting Application Insights integration.
#>

Write-Host "🔍 Application Insights Telemetry Diagnostics" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Check environment variables
Write-Host "1️⃣ Checking Environment Configuration..." -ForegroundColor Yellow
Write-Host ""

$connectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
$instrumentationKey = $env:APPINSIGHTS_INSTRUMENTATIONKEY

if ($connectionString) {
    Write-Host "  ✓ APPLICATIONINSIGHTS_CONNECTION_STRING is set" -ForegroundColor Green
    
    # Parse connection string
    if ($connectionString -match "InstrumentationKey=([^;]+)") {
        $key = $matches[1]
        Write-Host "    Instrumentation Key: $key" -ForegroundColor Gray
    }
    if ($connectionString -match "IngestionEndpoint=([^;]+)") {
        $endpoint = $matches[1]
        Write-Host "    Ingestion Endpoint: $endpoint" -ForegroundColor Gray
    }
} elseif ($instrumentationKey) {
    Write-Host "  ✓ APPINSIGHTS_INSTRUMENTATIONKEY is set" -ForegroundColor Green
    Write-Host "    Key: $instrumentationKey" -ForegroundColor Gray
} else {
    Write-Host "  ❌ No Application Insights configuration found!" -ForegroundColor Red
}

Write-Host ""

# Check .env file
Write-Host "2️⃣ Checking .env File..." -ForegroundColor Yellow
Write-Host ""

if (Test-Path ".env") {
    Write-Host "  ✓ .env file exists" -ForegroundColor Green
    
    $envContent = Get-Content ".env"
    $hasConnectionString = $envContent | Where-Object { $_ -match "^APPLICATIONINSIGHTS_CONNECTION_STRING=" }
    $hasInstrumentationKey = $envContent | Where-Object { $_ -match "^APPINSIGHTS_INSTRUMENTATIONKEY=" }
    
    if ($hasConnectionString) {
        Write-Host "    ✓ Contains APPLICATIONINSIGHTS_CONNECTION_STRING" -ForegroundColor Green
    }
    if ($hasInstrumentationKey) {
        Write-Host "    ✓ Contains APPINSIGHTS_INSTRUMENTATIONKEY" -ForegroundColor Green
    }
    
    # Check for other relevant settings
    $otelSettings = $envContent | Where-Object { $_ -match "^OTEL_" }
    if ($otelSettings) {
        Write-Host "    OpenTelemetry settings:" -ForegroundColor Gray
        foreach ($setting in $otelSettings) {
            if ($setting -notmatch "^#") {
                Write-Host "      $setting" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Host "  ⚠ No .env file found" -ForegroundColor Yellow
}

Write-Host ""

# Check if server is running
Write-Host "3️⃣ Checking Server Status..." -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8000/healthz" -Method Get -TimeoutSec 5
    Write-Host "  ✓ Server is running on http://localhost:8000" -ForegroundColor Green
    
    # Make a test request
    Write-Host ""
    Write-Host "4️⃣ Making Test Request..." -ForegroundColor Yellow
    Write-Host ""
    
    $testResponse = Invoke-RestMethod -Uri "http://localhost:8000/" -Method Get -TimeoutSec 10
    Write-Host "  ✓ Test request successful" -ForegroundColor Green
    Write-Host "    Response: $($testResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray
    
} catch {
    Write-Host "  ❌ Server is not running" -ForegroundColor Red
    Write-Host "    Start it with: .\start.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Provide recommendations
Write-Host "📋 Troubleshooting Checklist:" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Things to verify in Azure Portal:" -ForegroundColor Yellow
Write-Host "  1. Go to Azure Portal > Application Insights resource" -ForegroundColor White
Write-Host "  2. Check 'Live Metrics' - should show real-time data" -ForegroundColor White
Write-Host "  3. Check 'Transaction search' - should show individual requests" -ForegroundColor White
Write-Host "  4. Check 'Performance' blade - may take 2-3 minutes to populate" -ForegroundColor White
Write-Host "  5. Check 'Failures' blade - should show any errors" -ForegroundColor White
Write-Host ""

Write-Host "⚠ Common Issues:" -ForegroundColor Yellow
Write-Host "  • Data ingestion delay: Performance metrics can take 2-3 minutes" -ForegroundColor White
Write-Host "  • Live Metrics: Should appear immediately in the Live Metrics blade" -ForegroundColor White
Write-Host "  • Firewall: Ensure outbound HTTPS access to *.applicationinsights.azure.com" -ForegroundColor White
Write-Host "  • SDK version: Using azure-monitor-opentelemetry (latest)" -ForegroundColor White
Write-Host ""

Write-Host "🔧 Quick Fixes:" -ForegroundColor Yellow
Write-Host "  • Restart the application: Ctrl+C, then .\start.ps1" -ForegroundColor White
Write-Host "  • Generate more traffic: .\test-telemetry.ps1" -ForegroundColor White
Write-Host "  • Check logs: Look for telemetry-related messages in console output" -ForegroundColor White
Write-Host ""

Write-Host "📊 Expected Telemetry in Application Insights:" -ForegroundColor Cyan
Write-Host "  • Request Rate: Number of HTTP requests per second" -ForegroundColor White
Write-Host "  • Request Duration: Average response time (should show ~800ms for /slow)" -ForegroundColor White
Write-Host "  • Request Failures: Count of 4xx and 5xx responses" -ForegroundColor White
Write-Host "  • Dependencies: External HTTP calls to httpbin.org" -ForegroundColor White
Write-Host "  • Traces: Distributed tracing with spans" -ForegroundColor White
Write-Host "  • Custom Metrics: http.server.request.* metrics" -ForegroundColor White
Write-Host ""
