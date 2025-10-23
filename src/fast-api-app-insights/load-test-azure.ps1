#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run Locust load tests against Azure-deployed FastAPI instance

.DESCRIPTION
    Starts load testing against the Azure Web App with different scenarios:
    - Light: 5 users, 1/sec spawn rate, 60s duration
    - Medium: 20 users, 2/sec spawn rate, 120s duration
    - Heavy: 50 users, 5/sec spawn rate, 180s duration
    - Spike: 100 users, 10/sec spawn rate, 60s duration

.PARAMETER Scenario
    The test scenario to run (Light, Medium, Heavy, Spike, or Interactive)

.PARAMETER AppName
    The Azure Web App name (default: fast-api-app-insights-001)

.EXAMPLE
    .\load-test-azure.ps1 -Scenario Light
    .\load-test-azure.ps1 -Scenario Heavy -AppName my-custom-app-name
    .\load-test-azure.ps1 -Scenario Interactive
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Light", "Medium", "Heavy", "Spike", "Interactive")]
    [string]$Scenario = "Interactive",
    
    [Parameter(Mandatory = $false)]
    [string]$AppName = "fast-api-app-insights-001"
)

$ErrorActionPreference = "Stop"
$host_url = "https://$AppName.azurewebsites.net"

Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "FastAPI Load Test - Azure Environment" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "Scenario: $Scenario" -ForegroundColor Yellow
Write-Host "Target: $host_url" -ForegroundColor Yellow
Write-Host "==============================================================`n" -ForegroundColor Cyan

# Check if the app is accessible
Write-Host "Checking if Azure Web App is accessible..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$host_url/healthz" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ Azure Web App is running and healthy`n" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Azure Web App is not accessible at $host_url" -ForegroundColor Red
    Write-Host "  Possible issues:" -ForegroundColor Yellow
    Write-Host "    - App is not deployed yet (run: .\deploy.ps1)" -ForegroundColor Gray
    Write-Host "    - App is starting up (wait a few minutes)" -ForegroundColor Gray
    Write-Host "    - Wrong app name (check Azure portal)`n" -ForegroundColor Gray
    exit 1
}

# Check if locust is installed
Write-Host "Checking Locust installation..." -ForegroundColor Yellow
try {
    $locustVersion = locust --version 2>$null
    Write-Host "✓ Locust is installed: $locustVersion`n" -ForegroundColor Green
} catch {
    Write-Host "✗ Locust is not installed" -ForegroundColor Red
    Write-Host "  Install it with: pip install locust`n" -ForegroundColor Yellow
    exit 1
}

# Create reports directory if it doesn't exist
if (-not (Test-Path "reports")) {
    New-Item -ItemType Directory -Path "reports" | Out-Null
}

# Run the appropriate scenario
switch ($Scenario) {
    "Light" {
        Write-Host "Running LIGHT load test..." -ForegroundColor Cyan
        Write-Host "  - 5 concurrent users" -ForegroundColor Gray
        Write-Host "  - 1 user spawned per second" -ForegroundColor Gray
        Write-Host "  - 60 second duration`n" -ForegroundColor Gray
        
        locust --host=$host_url `
               --users 5 `
               --spawn-rate 1 `
               --run-time 60s `
               --headless `
               --html reports/load-test-azure-light.html `
               --csv reports/load-test-azure-light
    }
    
    "Medium" {
        Write-Host "Running MEDIUM load test..." -ForegroundColor Cyan
        Write-Host "  - 20 concurrent users" -ForegroundColor Gray
        Write-Host "  - 2 users spawned per second" -ForegroundColor Gray
        Write-Host "  - 120 second duration`n" -ForegroundColor Gray
        
        locust --host=$host_url `
               --users 20 `
               --spawn-rate 2 `
               --run-time 120s `
               --headless `
               --html reports/load-test-azure-medium.html `
               --csv reports/load-test-azure-medium
    }
    
    "Heavy" {
        Write-Host "Running HEAVY load test..." -ForegroundColor Cyan
        Write-Host "  - 50 concurrent users" -ForegroundColor Gray
        Write-Host "  - 5 users spawned per second" -ForegroundColor Gray
        Write-Host "  - 180 second duration`n" -ForegroundColor Gray
        
        locust --host=$host_url `
               --users 50 `
               --spawn-rate 5 `
               --run-time 180s `
               --headless `
               --html reports/load-test-azure-heavy.html `
               --csv reports/load-test-azure-heavy
    }
    
    "Spike" {
        Write-Host "Running SPIKE load test..." -ForegroundColor Cyan
        Write-Host "  - 100 concurrent users (spike traffic)" -ForegroundColor Gray
        Write-Host "  - 10 users spawned per second" -ForegroundColor Gray
        Write-Host "  - 60 second duration" -ForegroundColor Gray
        Write-Host "  - Using SpikeUser class`n" -ForegroundColor Gray
        
        locust --host=$host_url `
               --users 100 `
               --spawn-rate 10 `
               --run-time 60s `
               --headless `
               --html reports/load-test-azure-spike.html `
               --csv reports/load-test-azure-spike `
               --user-classes SpikeUser
    }
    
    "Interactive" {
        Write-Host "Starting INTERACTIVE mode..." -ForegroundColor Cyan
        Write-Host "  - Web UI will open at http://localhost:8089" -ForegroundColor Gray
        Write-Host "  - Configure users and spawn rate in the browser" -ForegroundColor Gray
        Write-Host "  - Press Ctrl+C to stop`n" -ForegroundColor Gray
        
        locust --host=$host_url
    }
}

Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "Load Test Complete!" -ForegroundColor Green
Write-Host "==============================================================`n" -ForegroundColor Cyan

if ($Scenario -ne "Interactive") {
    Write-Host "Reports generated in ./reports/ directory:" -ForegroundColor Yellow
    Write-Host "  - HTML report: load-test-azure-$($Scenario.ToLower()).html" -ForegroundColor Gray
    Write-Host "  - CSV stats: load-test-azure-$($Scenario.ToLower())_stats.csv" -ForegroundColor Gray
    Write-Host "  - CSV failures: load-test-azure-$($Scenario.ToLower())_failures.csv" -ForegroundColor Gray
    Write-Host "  - CSV history: load-test-azure-$($Scenario.ToLower())_stats_history.csv`n" -ForegroundColor Gray
}

Write-Host "Check Application Insights in Azure Portal:" -ForegroundColor Yellow
Write-Host "  Portal: https://portal.azure.com" -ForegroundColor Gray
Write-Host "  Resource: $AppName" -ForegroundColor Gray
Write-Host "  Views:" -ForegroundColor Gray
Write-Host "    - Live Metrics Stream" -ForegroundColor Gray
Write-Host "    - Transaction Search" -ForegroundColor Gray
Write-Host "    - Performance Blade" -ForegroundColor Gray
Write-Host "    - Application Map" -ForegroundColor Gray
Write-Host "    - Failures Blade`n" -ForegroundColor Gray
