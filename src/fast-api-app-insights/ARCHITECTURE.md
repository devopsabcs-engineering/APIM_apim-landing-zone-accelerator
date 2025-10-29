# Architecture Overview

## � Problem & Solution

### Problem Statement
FastAPI application with Azure Monitor OpenTelemetry was sending telemetry but **requests were not appearing** in Application Insights:
- ❌ Performance blade showed no request metrics
- ❌ Transaction Search showed 0 REQUEST events (only TRACES)
- ❌ Live Metrics showed no incoming request data

### Root Cause
The automatic FastAPI instrumentation from `azure-monitor-opentelemetry` was creating OpenTelemetry spans, but **Azure Monitor was not classifying them as REQUEST telemetry type**. The spans were being exported as TRACES instead of REQUESTS.

### Working Solution
1. **Disabled automatic FastAPI instrumentation** in `configure_azure_monitor()`
2. **Created custom middleware** that manually creates SERVER spans with ALL required HTTP semantic convention attributes
3. **Applied middleware BEFORE app startup** to avoid timing issues
4. **Enabled Live Metrics** via QuickPulse for real-time monitoring

## �🏗️ Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FastAPI Application                       │
│                                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Starlette Request Pipeline                        │    │
│  │                                                     │    │
│  │  1. HTTP Request arrives                           │    │
│  │  2. RequestTelemetryMiddleware intercepts         │    │
│  │     │                                              │    │
│  │     ├─> Create span (SpanKind.SERVER)            │    │
│  │     ├─> Set HTTP attributes                       │    │
│  │     │   ├─ http.method                           │    │
│  │     │   ├─ http.url                              │    │
│  │     │   ├─ http.target                           │    │
│  │     │   ├─ http.status_code                      │    │
│  │     │   └─ ... (all semantic conventions)        │    │
│  │     │                                              │    │
│  │     └─> Call next middleware/endpoint            │    │
│  │                                                     │    │
│  │  3. FastAPI endpoint processes request            │    │
│  │  4. Response returned through middleware          │    │
│  │  5. Span ends (telemetry sent)                    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │  OpenTelemetry SDK                                 │    │
│  │                                                     │    │
│  │  ├─ Tracer Provider                               │    │
│  │  ├─ Meter Provider                                │    │
│  │  └─ Logger Provider                               │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Telemetry Export
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         azure-monitor-opentelemetry (Distro)                │
│                                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Azure Monitor Exporters                           │    │
│  │                                                     │    │
│  │  ├─ Trace Exporter                                │    │
│  │  │   └─> Maps SERVER spans → REQUEST telemetry   │    │
│  │  │                                                  │    │
│  │  ├─ Metric Exporter                               │    │
│  │  │   └─> Custom metrics (duration, count, etc.)   │    │
│  │  │                                                  │    │
│  │  └─ QuickPulse (Live Metrics)                     │    │
│  │      └─> Real-time streaming                      │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Azure Application Insights                      │
│                                                               │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Ingestion      │  │  Live Endpoint  │                  │
│  │  Endpoint       │  │  (QuickPulse)   │                  │
│  └────────┬────────┘  └────────┬────────┘                  │
│           │                    │                             │
│           ▼                    ▼                             │
│  ┌──────────────────────────────────────────────┐          │
│  │          Data Processing & Storage           │          │
│  │                                                │          │
│  │  • REQUEST telemetry classification          │          │
│  │  • Correlation & aggregation                 │          │
│  │  • Metric calculation                        │          │
│  └──────────────────────────────────────────────┘          │
│                                                               │
│  ┌──────────────────────────────────────────────┐          │
│  │              Portal Visualization             │          │
│  │                                                │          │
│  │  ├─ Performance Blade                        │          │
│  │  │   • Request rate chart                    │          │
│  │  │   • Duration metrics (avg/p95/p99)        │          │
│  │  │   • Failure rate percentage               │          │
│  │  │                                            │          │
│  │  ├─ Live Metrics                             │          │
│  │  │   • Real-time request stream              │          │
│  │  │   • Server health metrics                 │          │
│  │  │                                            │          │
│  │  ├─ Transaction Search                       │          │
│  │  │   • REQUEST events queryable              │          │
│  │  │   • Full HTTP attribute details           │          │
│  │  │                                            │          │
│  │  └─ Application Map                          │          │
│  │      • Dependency visualization               │          │
│  │      • End-to-end tracing                    │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## 🔑 Critical Components

### RequestTelemetryMiddleware
**Location:** `telemetry_v2.py`

**Purpose:** Intercepts every HTTP request and creates OpenTelemetry spans with proper attributes

**Key Features:**
- Sets `SpanKind.SERVER` (required for REQUEST classification)
- Adds ALL HTTP semantic convention attributes
- Records request duration
- Handles exceptions and sets error status
- Logs each request for debugging

### Azure Monitor Configuration
**Location:** `telemetry_v2.py` → `configure_telemetry()`

**Key Settings:**
```python
configure_azure_monitor(
    connection_string=conn_str,
    enable_live_metrics=True,      # ← QuickPulse streaming
    resource=resource,              # ← Service name/version
    instrumentation_options={
        "fastapi": {"enabled": False},  # ← Disable automatic
        "httpx": {"enabled": True},     # ← Track dependencies
    }
)
```

### HTTP Semantic Conventions
**Required Attributes for REQUEST Classification:**

| Attribute | Example | Purpose |
|-----------|---------|---------|
| `http.method` | `GET` | HTTP verb |
| `http.url` | `http://localhost:8000/api` | Full URL |
| `http.target` | `/api` | Path only |
| `http.scheme` | `http` | Protocol |
| `http.host` | `localhost:8000` | Host + port |
| `http.status_code` | `200` | Response status |
| `http.flavor` | `1.1` | HTTP version |

**Without these:** Span classified as TRACE ❌  
**With these:** Span classified as REQUEST ✅

## 🔄 Data Flow

### 1. Request Arrives
```
Client → FastAPI → RequestTelemetryMiddleware
```

### 2. Span Created
```
Middleware → OpenTelemetry Tracer → Create span (SERVER kind)
                                   → Set HTTP attributes
```

### 3. Request Processed
```
Middleware → FastAPI endpoint → Business logic
                              → External dependencies (if any)
```

### 4. Response & Telemetry
```
Response → Middleware → Set status_code attribute
                      → End span
                      → OpenTelemetry SDK buffers telemetry
```

### 5. Export to Azure
```
SDK → Azure Monitor Exporter → HTTPS POST to Ingestion Endpoint
                             → Data includes:
                               • Span with SERVER kind
                               • All HTTP attributes
                               • Duration
                               • Status
```

### 6. Classification & Storage
```
Azure Monitor → Recognizes SERVER span + HTTP attributes
             → Classifies as REQUEST telemetry type
             → Stores in Application Insights
             → Updates metrics & dashboards
```

### 7. Portal Display
```
Application Insights → Performance blade updated
                     → Live Metrics stream active
                     → Transaction Search shows REQUESTS
                     → Application Map shows dependencies
```

## ⚙️ Why Custom Middleware Works

### Problem with Automatic Instrumentation
```python
# This DOESN'T work reliably:
configure_azure_monitor(
    instrumentation_options={"fastapi": {"enabled": True}}
)
```

**Issues:**
- Some HTTP attributes missing or inconsistent
- Span kind not always set to SERVER
- Azure Monitor mapping logic fails
- Results in TRACE classification instead of REQUEST

### Solution with Custom Middleware
```python
# This WORKS:
class RequestTelemetryMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        with _tracer.start_as_current_span(
            name=f"{request.method} {request.url.path}",
            kind=trace.SpanKind.SERVER,  # ← Explicit SERVER kind
        ) as span:
            # Set EVERY required attribute explicitly
            span.set_attribute("http.method", request.method)
            span.set_attribute("http.url", str(request.url))
            # ... etc (see telemetry_v2.py for full list)
```

**Benefits:**
- Full control over span attributes
- Guaranteed SpanKind.SERVER
- All HTTP semantic conventions present
- Azure Monitor correctly classifies as REQUEST
- Reliable across different environments

## 📊 Telemetry Types

### REQUEST (What We Want) ✅
- Appears in Performance blade
- Queryable in Transaction Search as "Request"
- Shows in Live Metrics as incoming requests
- Counted for request rate/duration metrics

### TRACE (What We Had Before) ❌
- Only appears in Logs/Traces
- Not counted in request metrics
- Doesn't populate Performance blade
- Not classified as HTTP request

### DEPENDENCY
- Outgoing HTTP calls (tracked by httpx instrumentation)
- Shown in Application Map
- Correlated with parent REQUEST

## 🎯 Success Metrics

You know it's working when Azure Portal shows:

1. **Performance Blade:**
   - Request rate chart with data points
   - Average duration metrics
   - Failure rate percentage

2. **Live Metrics:**
   - "Incoming Requests" section populated
   - Request Duration chart active
   - Sample telemetry streaming

3. **Transaction Search:**
   - Filter by "Request" event type shows results
   - Each request has full HTTP details
   - Status codes, URLs, durations all present

4. **Application Map:**
   - Your service node appears
   - Dependencies shown (httpbin.org)
   - End-to-end trace correlation works

## 🔗 Component Relationships

```
main.py
  ├─> Imports telemetry_v2
  ├─> Creates FastAPI app
  ├─> Calls configure_telemetry(app) in lifespan
  └─> Defines endpoints (/, /healthz, /slow, /chain, /error)

telemetry_v2.py
  ├─> Defines RequestTelemetryMiddleware class
  ├─> configure_azure_monitor() setup
  ├─> Adds middleware to app
  └─> Returns configured tracer

RequestTelemetryMiddleware
  ├─> Intercepts every HTTP request
  ├─> Creates OpenTelemetry span (SERVER kind)
  ├─> Sets all HTTP attributes
  ├─> Calls next handler
  └─> Ends span (triggers export)

OpenTelemetry SDK
  ├─> Collects spans, metrics, logs
  ├─> Batches telemetry
  └─> Exports to Azure Monitor

Azure Monitor Exporter
  ├─> Maps spans to Application Insights telemetry types
  ├─> REQUEST: SERVER spans with HTTP attributes
  ├─> DEPENDENCY: CLIENT spans
  └─> TRACE: Other spans or log entries

Application Insights
  ├─> Receives telemetry via REST API
  ├─> Processes & stores data
  ├─> Calculates metrics & aggregations
  └─> Serves to Portal UI
```

## � CI/CD Pipeline Architecture

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: Set Version                                        │
│                                                               │
│  1. Checkout with full Git history (fetchDepth: 0)          │
│  2. Install GitVersion tools                                 │
│  3. Calculate semantic version (e.g., 1.2.3)                │
│  4. Create and push Git tag                                  │
│                                                               │
│  Output: GitVersion.SemVer variable                         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: Build                                              │
│                                                               │
│  1. Checkout source code                                     │
│  2. Install Python dependencies to package folder            │
│  3. Copy application files (main.py, telemetry_v2.py)       │
│  4. Replace __VERSION__ placeholder with GitVersion.SemVer   │
│     (using sed command on deployed main.py)                  │
│  5. Clean up unnecessary files (tests, docs, cache)         │
│  6. Create deployment ZIP archive                            │
│  7. Publish build artifact                                   │
│                                                               │
│  Output: Deployment package with baked-in version           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 3: Deploy                                             │
│                                                               │
│  1. Checkout (for bicep template access)                    │
│  2. Calculate GitVersion.SemVer again                        │
│  3. Download build artifact (ZIP package)                    │
│  4. Deploy Bicep template with parameters:                   │
│     ├─ appName, location, SKU                               │
│     ├─ deploymentEnvironment=production                      │
│     └─ appVersion=$(GitVersion.SemVer)                      │
│  5. Configure Web App deployment settings                    │
│  6. Deploy application package to Azure Web App              │
│                                                               │
│  Output: Running application with version environment vars   │
└─────────────────────────────────────────────────────────────┘
```

### Version Flow

```
Git Commit → GitVersion Calculation → Git Tag Creation
                 │                          │
                 │                          └─> Pushed to repo (e.g., "1.2.3")
                 │
                 ├─> Build: Replace __VERSION__ in main.py
                 │   (Baked into deployed code)
                 │
                 └─> Deploy: Pass to Bicep as parameter
                     └─> Set as APP_VERSION env var in Azure
```

### Version Endpoint Strategy

The `/version` endpoint uses a fallback mechanism:

1. **Primary**: Baked-in `VERSION` constant (replaced during build)
2. **Fallback**: `APP_VERSION` environment variable (set by Bicep)
3. **Default**: `"local-dev"` (for local development)

This ensures version is always available even if one mechanism fails.

## 🔧 Infrastructure as Code

### Bicep Template Components

```
main.bicep
  │
  ├─> App Service Plan
  │   ├─ SKU: Configurable (default B1)
  │   ├─ OS: Linux
  │   └─ Reserved: true (Linux requirement)
  │
  ├─> Application Insights
  │   ├─ Application_Type: web
  │   ├─ Flow_Type: Bluefield
  │   └─ IngestionMode: ApplicationInsights
  │
  └─> Web App
      ├─ Runtime: PYTHON|3.13
      ├─ Startup Command: python -m uvicorn main:app --host 0.0.0.0 --port 8000
      ├─ Identity: System-assigned managed identity
      └─ App Settings:
          ├─ APPLICATIONINSIGHTS_CONNECTION_STRING (from AI resource)
          ├─ APPINSIGHTS_INSTRUMENTATIONKEY (from AI resource)
          ├─ OTEL_SERVICE_NAME (from appName parameter)
          ├─ OTEL_EXPORTER_AZUREMONITOR_LIVEMETRICS_ENABLED=true
          ├─ DEPLOYMENT_ENVIRONMENT (from parameter, e.g., "production")
          └─ APP_VERSION (from parameter, e.g., "1.2.3")
```

### Environment Variables Flow

```
Pipeline Parameter (deploymentEnvironment) 
    → Bicep Parameter 
    → App Setting (DEPLOYMENT_ENVIRONMENT)
    → Python os.getenv("DEPLOYMENT_ENVIRONMENT")
    → /version endpoint response

Pipeline Variable (GitVersion.SemVer)
    → Bicep Parameter (appVersion)
    → App Setting (APP_VERSION)
    → Python os.getenv("APP_VERSION")
    → /version endpoint fallback
```

## 📊 Telemetry Types & Classification

### REQUEST (What We Achieve) ✅
- Appears in Performance blade
- Queryable in Transaction Search as "Request"
- Shows in Live Metrics as incoming requests
- Counted for request rate/duration metrics
- **Requirements**: SpanKind.SERVER + all HTTP attributes

### TRACE (What Automatic Instrumentation Produced) ❌
- Only appears in Logs/Traces
- Not counted in request metrics
- Doesn't populate Performance blade
- Not classified as HTTP request
- **Cause**: Missing attributes or wrong SpanKind

### DEPENDENCY
- Outgoing HTTP calls (tracked by httpx instrumentation)
- Shown in Application Map
- Correlated with parent REQUEST
- **SpanKind**: CLIENT

## ✅ Success Criteria

You know it's working when Azure Portal shows:

### 1. Performance Blade
- Request rate chart with data points
- Average duration metrics (with P95/P99)
- Failure rate percentage

### 2. Live Metrics
- "Incoming Requests" section populated in real-time
- Request Duration chart streaming
- Sample telemetry showing individual requests
- Server health metrics (CPU, Memory)

### 3. Transaction Search
- Filter by "Request" event type shows results
- Each request has full HTTP details
- Status codes, URLs, durations all present
- Correlation IDs linking requests to dependencies

### 4. Application Map
- Your service node appears
- Dependencies shown (httpbin.org calls)
- End-to-end trace correlation works

### 5. Version Endpoint
- Returns semantic version (e.g., "1.2.3")
- Environment shows correct value (e.g., "production")
- Version matches Git tag in repository

## 🐛 Troubleshooting

### Issue: No requests appearing
**Root Causes:**
- Connection string not configured
- Middleware not added before app startup
- SpanKind not set to SERVER
- Required HTTP attributes missing

**Solution:**
- Verify `.env` file or Azure app settings
- Check `telemetry_v2.py` is being used
- Confirm middleware registration order in `main.py`

### Issue: Requests appearing as TRACES
**Root Cause:**
- Using automatic FastAPI instrumentation
- Missing HTTP semantic convention attributes

**Solution:**
- Disable automatic instrumentation: `"fastapi": {"enabled": False}`
- Use `RequestTelemetryMiddleware` from `telemetry_v2.py`

### Issue: Live Metrics not showing data
**Root Causes:**
- Live Metrics not enabled in configuration
- Missing LiveEndpoint in connection string
- Page not actively focused (browser tab in background)

**Solution:**
- Set `enable_live_metrics=True` in configure_azure_monitor
- Ensure connection string includes `LiveEndpoint=https://...`
- Keep Live Metrics page in active browser tab

### Issue: Version showing "local-dev"
**Root Causes:**
- Application deployed manually (not via pipeline)
- Version replacement failed during build
- APP_VERSION environment variable not set

**Solution:**
- Deploy via CI/CD pipeline
- Check build logs for sed command success
- Verify Bicep deployment included appVersion parameter
- Check Azure App Service configuration for APP_VERSION setting

## 📚 Further Reading

- [README.md](README.md) - Quick start guide and usage
- [OpenTelemetry HTTP Conventions](https://opentelemetry.io/docs/specs/semconv/http/)
- [Azure Monitor Data Model](https://learn.microsoft.com/en-us/azure/azure-monitor/app/data-model-complete)
- [GitVersion Documentation](https://gitversion.net/docs/)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

