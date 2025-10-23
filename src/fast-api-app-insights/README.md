# FastAPI + Azure Application Insights Demo

Simple FastAPI app instrumented with OpenTelemetry exporters for Azure Application Insights. Uses a Python 3.13 virtual environment and auto instrumentation patterns inspired by the referenced articles.

## Prerequisites

- Python 3.13 installed and available as `python` or `python3`
- An Application Insights resource with either a connection string or instrumentation key

## Setup

```pwsh
# from repo root or this folder
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

> **Note**: This app uses the `azure-monitor-opentelemetry` distro package which automatically instruments FastAPI, httpx, and other common libraries for distributed tracing and live metrics.

## API Endpoints

The FastAPI application includes these endpoints:

- **`GET /`** - Root endpoint with external API call to httpbin.org (good for basic tracing)
- **`GET /healthz`** - Health check endpoint (lightweight, no external calls)
- **`GET /slow`** - Simulates slow processing with multiple external calls (~0.8s)
- **`GET /chain`** - Makes 3 sequential API calls to demonstrate trace chains
- **`GET /error`** - Intentionally raises an exception to test error tracking

Export your Application Insights connection string (preferred) or instrumentation key before running the app (environment variables can also be stored in a local `.env` file that the app loads on startup):

```pwsh
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=...;IngestionEndpoint=..."
# or fallback
# $env:APPINSIGHTS_INSTRUMENTATIONKEY = "00000000-0000-0000-0000-000000000000"
# optional overrides
# $env:OTEL_SERVICE_NAME = "fast-api-app"
# $env:OTEL_SERVICE_NAMESPACE = "sample"
```

## API Endpoints

The FastAPI application includes these endpoints:

- **`GET /`** - Root endpoint with external API call to httpbin.org (good for basic tracing)
- **`GET /healthz`** - Health check endpoint (lightweight, no external calls)
- **`GET /slow`** - Simulates slow processing with multiple external calls (~0.8s)
- **`GET /chain`** - Makes 3 sequential API calls to demonstrate trace chains
- **`GET /error`** - Intentionally raises an exception to test error tracking

## Run the API

```pwsh
uvicorn main:app --host 0.0.0.0 --port 8000
```

Hit `http://localhost:8000/` to generate traces, metrics, and logs. The `/healthz` endpoint provides a simple health probe.

Logs, traces, and metrics flow to Application Insights using the Azure Monitor exporters when the connection string is present. Live Metrics streaming is enabled automatically; no portal-side configuration changes are required. If you are running outside Azure, ensure outbound access to the configured ingestion endpoint so the live stream can connect.

### API Documentation

FastAPI provides automatic interactive API documentation:

- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs) - Interactive API explorer
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc) - Alternative documentation
- **OpenAPI JSON**: [http://localhost:8000/openapi.json](http://localhost:8000/openapi.json) - Raw OpenAPI 3.0 specification

To export the OpenAPI spec to a file:

```pwsh
python export-openapi.py
# Or specify custom output
python export-openapi.py --output api-spec.json
```

## Deployment

Use the PowerShell deployment script to provision infrastructure and deploy the app to Azure:

```pwsh
.\deploy.ps1 -ResourceGroupName 'rg-fast-api-app-insights-001' -Location 'canadacentral' -AppName 'fast-api-app-insights-001'
```

Or use the Azure DevOps pipeline (`azure-pipelines.yml`) for CI/CD automation.

## Load Testing

This project includes Locust-based load tests to generate telemetry data and test performance.

### Local Load Testing

Test your local development environment:

```pwsh
# Interactive mode - opens web UI at http://localhost:8089
.\load-test-local.ps1 -Scenario Interactive

# Pre-configured scenarios (headless mode)
.\load-test-local.ps1 -Scenario Light    # 5 users, 60s
.\load-test-local.ps1 -Scenario Medium   # 20 users, 120s
.\load-test-local.ps1 -Scenario Heavy    # 50 users, 180s
.\load-test-local.ps1 -Scenario Spike    # 100 users, 60s (spike traffic)
```

### Azure Load Testing

Test your deployed Azure Web App:

```pwsh
# Interactive mode
.\load-test-azure.ps1 -Scenario Interactive

# Pre-configured scenarios
.\load-test-azure.ps1 -Scenario Light
.\load-test-azure.ps1 -Scenario Medium
.\load-test-azure.ps1 -Scenario Heavy
.\load-test-azure.ps1 -Scenario Spike

# Custom app name
.\load-test-azure.ps1 -Scenario Medium -AppName my-app-name
```

### Advanced Locust Usage

Run Locust directly for more control:

```pwsh
# Local testing with custom parameters
locust --host=http://localhost:8000 --users 50 --spawn-rate 5 --run-time 120s

# Azure testing
locust --host=https://fast-api-app-insights-001.azurewebsites.net

# Use specific user class
locust --host=http://localhost:8000 --user-classes HeavyUser

# Generate reports
locust --host=http://localhost:8000 --headless --html report.html --csv results
```

### Load Test Reports

Headless mode generates reports in the `reports/` directory:
- **HTML Report**: Visual summary with charts
- **CSV Stats**: Detailed request statistics
- **CSV Failures**: Failed request details
- **CSV History**: Time-series data for analysis

## Troubleshooting

- **No traces appearing**: Ensure you've installed all dependencies including `opentelemetry-instrumentation-httpx` and restarted the app after updating `requirements.txt`.
- **Live Metrics not showing**: Live Metrics can take 1-2 minutes to establish connection after app startup. Verify outbound HTTPS access to the LiveEndpoint in your connection string.
- **Missing connection string**: Ensure the connection string or instrumentation key environment variable is set before starting the app (check `.env` file or environment variables).
- Use `pip list` to confirm the expected OpenTelemetry packages are installed.
- If running behind a proxy, set the appropriate proxy variables so the exporter can reach Azure Monitor.
- To suppress the local warning about missing `azure_app_service` detector, set `OTEL_PYTHON_RESOURCE_DETECTORS=env,process` before launching `uvicorn`.
