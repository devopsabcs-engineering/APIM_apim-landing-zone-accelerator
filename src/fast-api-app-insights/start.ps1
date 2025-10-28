#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start the FastAPI application with Application Insights telemetry.

.DESCRIPTION
    This script activates the Python virtual environment, checks for required
    environment variables, and starts the FastAPI application using uvicorn.

.PARAMETER Port
    The port to run the application on. Default: 8000

.PARAMETER Host
    The host to bind to. Default: 0.0.0.0

.PARAMETER Reload
    Enable auto-reload for development. Default: false

.PARAMETER Workers
    Number of worker processes. Default: 1

.EXAMPLE
    .\start.ps1
    Start the application with default settings

.EXAMPLE
    .\start.ps1 -Port 8080 -Reload
    Start with auto-reload on port 8080

.EXAMPLE
    .\start.ps1 -Workers 4
    Start with 4 worker processes for production
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port = 8000,

    [Parameter(Mandatory = $false)]
    [string]$HostAddress = "0.0.0.0",

    [Parameter(Mandatory = $false)]
    [switch]$Reload,

    [Parameter(Mandatory = $false)]
    [int]$Workers = 1
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "🚀 Starting FastAPI Application with Application Insights" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Check if virtual environment exists
$VenvPath = Join-Path $ScriptDir ".venv"
if (-not (Test-Path $VenvPath)) {
    Write-Host "❌ Virtual environment not found at: $VenvPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create it first:" -ForegroundColor Yellow
    Write-Host "  python -m venv .venv" -ForegroundColor White
    Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor White
    Write-Host "  pip install -r requirements.txt" -ForegroundColor White
    exit 1
}

# Activate virtual environment
$ActivateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
if (Test-Path $ActivateScript) {
    Write-Host "✓ Activating virtual environment..." -ForegroundColor Green
    & $ActivateScript
} else {
    Write-Host "❌ Activation script not found: $ActivateScript" -ForegroundColor Red
    exit 1
}

# Check for .env file and load it
$EnvFile = Join-Path $ScriptDir ".env"
if (Test-Path $EnvFile) {
    Write-Host "✓ Found .env file, loading environment variables..." -ForegroundColor Green
    
    # Parse and load .env file
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -and -not $line.StartsWith("#")) {
            # Parse KEY=VALUE or KEY="VALUE"
            if ($line -match '^([^=]+)=(.+)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove surrounding quotes if present
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }
                
                # Set environment variable
                Set-Item -Path "env:$key" -Value $value
                Write-Host "  Loaded: $key" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "⚠ No .env file found" -ForegroundColor Yellow
}

# Check for Application Insights configuration
$ConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
$InstrumentationKey = $env:APPINSIGHTS_INSTRUMENTATIONKEY

if (-not $ConnectionString -and -not $InstrumentationKey) {
    Write-Host ""
    Write-Host "⚠ WARNING: No Application Insights configuration found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Set one of the following environment variables:" -ForegroundColor Yellow
    Write-Host "  Option 1 (Recommended):" -ForegroundColor White
    Write-Host '    $env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=...;IngestionEndpoint=..."' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Option 2 (Legacy):" -ForegroundColor White
    Write-Host '    $env:APPINSIGHTS_INSTRUMENTATIONKEY = "00000000-0000-0000-0000-000000000000"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or add to .env file:" -ForegroundColor White
    Write-Host '    APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...;IngestionEndpoint=...' -ForegroundColor Cyan
    Write-Host ""
    
    $Continue = Read-Host "Continue without Application Insights? (y/N)"
    if ($Continue -ne "y" -and $Continue -ne "Y") {
        Write-Host "❌ Exiting..." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Application Insights configuration found" -ForegroundColor Green
    if ($ConnectionString) {
        $MaskedConn = $ConnectionString -replace "InstrumentationKey=[^;]+", "InstrumentationKey=***"
        Write-Host "  Connection String: $MaskedConn" -ForegroundColor Gray
    }
}

# Set optional environment variables
$env:APP_HOST = $HostAddress
$env:APP_PORT = $Port

# Display configuration
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Host:       $HostAddress" -ForegroundColor White
Write-Host "  Port:       $Port" -ForegroundColor White
Write-Host "  Workers:    $Workers" -ForegroundColor White
Write-Host "  Auto-reload: $($Reload.IsPresent)" -ForegroundColor White
Write-Host ""

# Build uvicorn command
$UvicornArgs = @(
    "main:app"
    "--host", $HostAddress
    "--port", $Port
    "--workers", $Workers
)

if ($Reload) {
    $UvicornArgs += "--reload"
}

# Display startup information
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Starting uvicorn server..." -ForegroundColor Green
Write-Host ""
Write-Host "📖 API Documentation:" -ForegroundColor Cyan
Write-Host "   Swagger UI: http://localhost:$Port/docs" -ForegroundColor White
Write-Host "   ReDoc:      http://localhost:$Port/redoc" -ForegroundColor White
Write-Host "   OpenAPI:    http://localhost:$Port/openapi.json" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Test Endpoints:" -ForegroundColor Cyan
Write-Host "   Root:       http://localhost:$Port/" -ForegroundColor White
Write-Host "   Health:     http://localhost:$Port/healthz" -ForegroundColor White
Write-Host "   Slow:       http://localhost:$Port/slow" -ForegroundColor White
Write-Host "   Chain:      http://localhost:$Port/chain" -ForegroundColor White
Write-Host "   Error:      http://localhost:$Port/error" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Start the application
try {
    uvicorn @UvicornArgs
} catch {
    Write-Host ""
    Write-Host "❌ Error starting application: $_" -ForegroundColor Red
    exit 1
}
