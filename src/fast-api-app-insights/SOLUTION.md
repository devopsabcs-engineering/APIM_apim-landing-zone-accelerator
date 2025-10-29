# Application Insights Integration Solution

## 🎯 Problem Statement

FastAPI application with Azure Monitor OpenTelemetry was sending telemetry but **requests were not appearing** in Application Insights:
- ❌ Performance blade showed no request metrics
- ❌ Transaction Search showed 0 REQUEST events (only TRACES)
- ❌ Live Metrics showed no incoming request data

## ✅ Root Cause

The automatic FastAPI instrumentation from `azure-monitor-opentelemetry` was creating OpenTelemetry spans, but **Azure Monitor was not classifying them as REQUEST telemetry type**. The spans were being exported as TRACES instead of REQUESTS, which prevented:
- Performance metrics from populating
- Request-based queries from working
- Live Metrics from showing request data

## 🔧 Working Solution

### Key Changes Made

1. **Disabled automatic FastAPI instrumentation** in `configure_azure_monitor()`
2. **Created custom middleware** that manually creates SERVER spans with ALL required HTTP semantic convention attributes
3. **Applied middleware BEFORE app startup** to avoid timing issues

### Implementation Details

#### File: `telemetry_v2.py`

**Critical Components:**

1. **Custom Middleware Class:**
```python
class RequestTelemetryMiddleware(BaseHTTPMiddleware):
    """Middleware that creates proper request telemetry using OpenTelemetry."""
    
    async def dispatch(self, request: Request, call_next):
        # Create a SERVER span with SpanKind.SERVER
        with _tracer.start_as_current_span(
            f"{request.method} {request.url.path}",
            kind=trace.SpanKind.SERVER,  # ← CRITICAL for REQUEST classification
        ) as span:
            # Set ALL required HTTP semantic convention attributes
            span.set_attribute("http.method", request.method)
            span.set_attribute("http.url", str(request.url))
            span.set_attribute("http.target", request.url.path)
            span.set_attribute("http.scheme", request.url.scheme)
            span.set_attribute("http.host", request.url.netloc)
            span.set_attribute("http.flavor", "1.1")
            span.set_attribute("http.status_code", response.status_code)
            # ... etc
```

2. **Azure Monitor Configuration:**
```python
configure_azure_monitor(
    connection_string=conn_str,
    enable_live_metrics=True,
    resource=resource,
    instrumentation_options={
        "fastapi": {"enabled": False},  # ← Disabled automatic instrumentation
        "httpx": {"enabled": True},     # ← Keep for external dependencies
    },
)
```

3. **Middleware Registration:**
```python
# Must be added BEFORE lifespan startup
app.add_middleware(RequestTelemetryMiddleware)
```

#### File: `main.py`

**Integration:**
```python
from telemetry_v2 import configure_telemetry

# Add middleware BEFORE lifespan
app.add_middleware(RequestTelemetryMiddleware)

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    configure_telemetry(app)
    yield
```

## 📊 What You Get

### Application Insights Performance Blade
- ✅ **Request Rate**: Real-time request count per second
- ✅ **Request Duration**: Average/P95/P99 response times
- ✅ **Request Failure Rate**: 4xx and 5xx error percentages

### Live Metrics
- ✅ **Incoming Requests**: Real-time streaming
- ✅ **Request Duration**: Live response time chart
- ✅ **Server Metrics**: CPU, Memory usage
- ✅ **Sample Telemetry**: Individual requests as they happen

### Transaction Search
- ✅ **REQUEST Event Type**: All HTTP requests properly classified
- ✅ **Full Request Details**: Method, URL, status, duration
- ✅ **HTTP Attributes**: All semantic convention properties
- ✅ **Correlated Dependencies**: External HTTP calls tracked

### Dependencies
- ✅ **External HTTP Calls**: Tracked via httpx instrumentation
- ✅ **End-to-End Tracing**: Full distributed trace correlation

## 🔍 Why This Works

### HTTP Semantic Conventions Required

Application Insights maps OpenTelemetry spans to REQUEST telemetry type when:

1. **Span Kind = SERVER** (`trace.SpanKind.SERVER`)
2. **Required Attributes Present:**
   - `http.method` - HTTP verb (GET, POST, etc.)
   - `http.url` - Full request URL
   - `http.target` - Path (e.g., `/api/users`)
   - `http.status_code` - Response status
   - `http.scheme` - Protocol (http/https)
   - `http.host` - Host and port

### What Didn't Work

❌ **Automatic FastAPI Instrumentation:** 
```python
instrumentation_options={"fastapi": {"enabled": True}}
```
- Created spans but missing some required attributes
- Azure Monitor classified as TRACE instead of REQUEST

❌ **FastAPIInstrumentor with hooks:**
```python
FastAPIInstrumentor().instrument_app(app, server_request_hook=...)
```
- Even with custom hooks, attribute mapping was inconsistent

❌ **Adding middleware after startup:**
```python
# Inside lifespan
app.add_middleware(...)  # ← Raises "Cannot add middleware after app started"
```

## 🚀 How to Use

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Environment
Create `.env` file:
```env
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...;IngestionEndpoint=...;LiveEndpoint=...
OTEL_SERVICE_NAME=fast-api-app-insights
OTEL_METRIC_EXPORT_INTERVAL=5000
OTEL_SEMCONV_STABILITY_OPT_IN=http
```

### 3. Start Server
```powershell
.\run-server.ps1
```

Or manually:
```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### 4. Send Test Traffic
```powershell
# Normal requests
Invoke-WebRequest -Uri "http://localhost:8000/" -UseBasicParsing

# Slow requests (test performance tracking)
Invoke-WebRequest -Uri "http://localhost:8000/slow" -UseBasicParsing

# Error requests (test failure tracking)
Invoke-WebRequest -Uri "http://localhost:8000/error" -UseBasicParsing

# Chain requests (test dependency tracking)
Invoke-WebRequest -Uri "http://localhost:8000/chain" -UseBasicParsing
```

### 5. View in Azure Portal
1. Navigate to Application Insights resource
2. **Performance Blade**: Investigate → Performance
3. **Live Metrics**: Investigate → Live Metrics
4. **Transaction Search**: Investigate → Transaction search (filter by "Request")

## 📝 Key Files

### Required Files
- **`telemetry_v2.py`**: Working telemetry configuration with custom middleware
- **`main.py`**: FastAPI application with proper middleware integration
- **`.env`**: Environment configuration with connection string
- **`requirements.txt`**: Python dependencies

### Helper Scripts
- **`run-server.ps1`**: Start server in separate window
- **`test-single-request.ps1`**: Send single test request

### Deprecated Files (can be removed)
- `telemetry.py` - Original implementation that didn't work
- `debug_telemetry.py` - Debugging script
- `diagnose-telemetry.ps1` - Diagnostic script
- `test-telemetry.ps1` - Old test script
- `verify-telemetry.ps1` - Old verification script
- `test-requests-final.ps1` - Old test script

## 🎓 Lessons Learned

1. **Azure Monitor is picky about span attributes**: Missing even one required HTTP attribute can cause misclassification
2. **SpanKind.SERVER is mandatory**: Without it, spans won't be recognized as requests
3. **Automatic instrumentation isn't always sufficient**: Sometimes manual control is needed
4. **Middleware timing matters**: Must be added before app startup
5. **Live Metrics backend success ≠ portal display**: Backend can be working while portal shows nothing due to classification issues

## 🔗 References

- [OpenTelemetry Semantic Conventions - HTTP](https://opentelemetry.io/docs/specs/semconv/http/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=python)
- [Application Insights Data Model](https://learn.microsoft.com/en-us/azure/azure-monitor/app/data-model-complete)

## ✅ Success Criteria

You know it's working when:

- ✅ Transaction Search shows **REQUEST** event type (not just traces)
- ✅ Performance blade shows request rate, duration, and failure metrics
- ✅ Live Metrics displays incoming requests in real-time
- ✅ Each request has full HTTP attributes (method, url, status, etc.)
- ✅ External dependencies (httpx calls) are tracked and correlated

## 🐛 Troubleshooting

### Issue: No requests appearing
**Check:**
1. Server logs show middleware is being invoked: `✅ Request: GET / -> 200`
2. Environment variable `APPLICATIONINSIGHTS_CONNECTION_STRING` is set
3. Middleware is added BEFORE lifespan startup
4. Azure Portal is showing "Last 30 minutes" time range

### Issue: Requests appearing as TRACES
**Check:**
1. Using `telemetry_v2.py` (not old `telemetry.py`)
2. `SpanKind.SERVER` is set in middleware
3. All required HTTP attributes are being set
4. FastAPI automatic instrumentation is DISABLED

### Issue: Live Metrics not showing data
**Check:**
1. `enable_live_metrics=True` in configure_azure_monitor
2. Connection string includes `LiveEndpoint=...`
3. Server logs show QuickPulse ping/post requests succeeding
4. Live Metrics page is actively open in browser (not just background tab)

### Issue: Dependencies not tracked
**Check:**
1. `httpx` instrumentation is enabled in instrumentation_options
2. Using `httpx.AsyncClient()` for external calls (not requests library)
3. Requests are made within an active span context
