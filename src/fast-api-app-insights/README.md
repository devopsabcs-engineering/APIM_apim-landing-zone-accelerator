# FastAPI + Azure Application Insights Demo

FastAPI application with **working** Azure Application Insights integration using OpenTelemetry. Features custom middleware that properly creates REQUEST telemetry for Application Insights Performance monitoring.

## ✅ What Works

- ✅ **Request tracking** - All HTTP requests appear in Performance blade
- ✅ **Live Metrics** - Real-time request rate and duration
- ✅ **Transaction Search** - Requests properly classified as REQUEST type
- ✅ **Dependency tracking** - External HTTP calls to httpbin.org
- ✅ **Error tracking** - Exception telemetry with correlation

## Prerequisites

- Python 3.9+ (tested with 3.13)
- Azure Application Insights resource with connection string

## Quick Start

### 1. Setup Virtual Environment

```pwsh
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Configure Application Insights

Create a `.env` file:

```env
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...;IngestionEndpoint=https://...;LiveEndpoint=https://...
OTEL_SERVICE_NAME=fast-api-app-insights
OTEL_METRIC_EXPORT_INTERVAL=5000
OTEL_SEMCONV_STABILITY_OPT_IN=http
```

### 3. Start Server

```pwsh
.\run-server.ps1
```

The server will start in a new window on `http://localhost:8000`

> **Important**: This solution uses **custom middleware** (`telemetry_v2.py`) to create proper REQUEST telemetry. See [SOLUTION.md](SOLUTION.md) for technical details on why automatic instrumentation didn't work.

## API Endpoints

- **`GET /`** - Root endpoint with external API call to httpbin.org
- **`GET /healthz`** - Health check endpoint (lightweight, no external calls)
- **`GET /slow`** - Simulates slow processing (~800ms with external calls)
- **`GET /chain`** - Makes 3 sequential API calls to demonstrate distributed tracing
- **`GET /error`** - Intentionally raises exception to test error tracking

### API Documentation

FastAPI provides automatic interactive API documentation:

- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs) - Interactive API explorer
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc) - Alternative documentation
- **OpenAPI JSON**: [http://localhost:8000/openapi.json](http://localhost:8000/openapi.json) - Raw OpenAPI 3.0 specification

## Testing

### Send Test Requests

```pwsh
# Single request
Invoke-WebRequest -Uri "http://localhost:8000/" -UseBasicParsing

# Slow request (test performance tracking)
Invoke-WebRequest -Uri "http://localhost:8000/slow" -UseBasicParsing

# Error request (test failure tracking)
try { Invoke-WebRequest -Uri "http://localhost:8000/error" -UseBasicParsing } catch { }

# Chain request (test dependency tracking)
Invoke-WebRequest -Uri "http://localhost:8000/chain" -UseBasicParsing
```

### View in Azure Portal

1. Navigate to your Application Insights resource
2. **Performance Blade**: Investigate → Performance
   - Request Rate, Duration, Failure Rate metrics
3. **Live Metrics**: Investigate → Live Metrics  
   - Real-time request streaming
4. **Transaction Search**: Investigate → Transaction search
   - Filter by event type: "Request"
   - View individual request details

## Monitoring Features

### What You'll See in Application Insights

**Performance Metrics:**
- Request rate per second
- Average/P95/P99 response times
- Failure rate percentages
- Server CPU/Memory metrics

**Request Details:**
- HTTP method, URL, status code
- Request duration
- All HTTP semantic convention attributes
- Correlated dependencies and traces

**Dependencies:**
- External HTTP calls tracked (httpbin.org)
- End-to-end distributed tracing
- Dependency duration and success rates

**Errors:**
- Exception telemetry with stack traces
- Correlated with parent requests
- Failure analysis and trends

## Project Structure

```
├── main.py                    # FastAPI application
├── telemetry_v2.py           # ✅ WORKING telemetry configuration
├── telemetry.py              # ❌ Deprecated (automatic instrumentation)
├── run-server.ps1            # Start server in new window
├── test-single-request.ps1   # Send test request
├── requirements.txt          # Python dependencies
├── .env                      # Environment configuration
├── README.md                 # This file
└── SOLUTION.md               # Technical deep-dive on solution
```

## Key Files

- **`telemetry_v2.py`**: Custom middleware that creates proper REQUEST telemetry
- **`main.py`**: FastAPI app with middleware integration
- **`SOLUTION.md`**: Complete technical explanation of the solution

## How It Works

This solution uses a **custom Starlette middleware** (`RequestTelemetryMiddleware`) that:

1. Creates OpenTelemetry spans with `SpanKind.SERVER`
2. Sets ALL required HTTP semantic convention attributes
3. Properly maps to Application Insights REQUEST telemetry type

The automatic FastAPI instrumentation was creating spans but Azure Monitor was classifying them as TRACES instead of REQUESTS. See [SOLUTION.md](SOLUTION.md) for full details.

## Troubleshooting

### No requests appearing in Application Insights

**Check:**
- `.env` file exists with valid `APPLICATIONINSIGHTS_CONNECTION_STRING`
- Server logs show: `✅ Request: GET / -> 200`
- Azure Portal time range is "Last 30 minutes"
- Using `telemetry_v2.py` (not old `telemetry.py`)

### Requests appearing as TRACES instead of REQUESTS

**Check:**
- Ensure you're using `telemetry_v2.py`
- Verify `SpanKind.SERVER` is set
- Confirm all HTTP attributes are present

### Live Metrics not showing data

**Check:**
- `enable_live_metrics=True` in configuration
- Connection string includes `LiveEndpoint=...`
- Live Metrics page is actively open (not background tab)
- Server logs show QuickPulse ping/post succeeding

See [SOLUTION.md](SOLUTION.md) for detailed troubleshooting guide.

## Load Testing

### Local Load Testing with Locust

Locust is included for local performance testing:

```pwsh
locust -f locustfile.py --host http://localhost:8000
```

Then open [http://localhost:8089](http://localhost:8089) to configure and run load tests.

Or use the PowerShell helper script:

```pwsh
.\load-test-local.ps1
```

Results are saved to the `reports/` directory.

## Export OpenAPI Specification

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

### Advanced Load Testing with Locust

```pwsh
# Local testing with custom parameters
locust --host=http://localhost:8000 --users 50 --spawn-rate 5 --run-time 120s

# Azure testing
locust --host=https://fast-api-app-insights-001.azurewebsites.net
```

### Load Test Reports

Headless mode generates reports in the `reports/` directory:

- **HTML Report**: Visual summary with charts
- **CSV Stats**: Detailed request statistics
- **CSV Failures**: Failed request details
- **CSV History**: Time-series data for analysis

## References

- [SOLUTION.md](SOLUTION.md) - Complete technical deep-dive on the working solution
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/http/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=python)
- [Application Insights Data Model](https://learn.microsoft.com/en-us/azure/azure-monitor/app/data-model-complete)

