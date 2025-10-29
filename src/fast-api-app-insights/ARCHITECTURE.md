# Architecture Overview

## 🏗️ Solution Architecture

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

## 📚 Further Reading

- [SOLUTION.md](SOLUTION.md) - Complete technical explanation
- [CHANGES.md](CHANGES.md) - What changed from before
- [README.md](README.md) - Quick start guide
- [OpenTelemetry HTTP Conventions](https://opentelemetry.io/docs/specs/semconv/http/)
- [Azure Monitor Data Model](https://learn.microsoft.com/en-us/azure/azure-monitor/app/data-model-complete)
