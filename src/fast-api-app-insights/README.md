# FastAPI + Azure Application Insights Demo

Simple FastAPI app instrumented with OpenTelemetry exporters for Azure Application Insights. Uses a Python 3.13 virtual environment and auto instrumentation patterns inspired by the referenced articles.

## Prerequisites

- Python 3.13 installed and available as `python` or `python3`
- An Application Insights resource with either a connection string or instrumentation key

## Setup

```pwsh
# from repo root or this folder
python -m venv .venv
\.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Export your Application Insights connection string (preferred) or instrumentation key before running the app (environment variables can also be stored in a local `.env` file that the app loads on startup):

```pwsh
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=...;IngestionEndpoint=..."
# or fallback
# $env:APPINSIGHTS_INSTRUMENTATIONKEY = "00000000-0000-0000-0000-000000000000"
# optional overrides
# $env:OTEL_SERVICE_NAME = "fast-api-app"
# $env:OTEL_SERVICE_NAMESPACE = "sample"
```

## Run the API

```pwsh
uvicorn main:app --host 0.0.0.0 --port 8000
```

Hit `http://localhost:8000/` to generate traces, metrics, and logs. The `/healthz` endpoint provides a simple health probe.

Logs, traces, and metrics flow to Application Insights using the Azure Monitor exporters when the connection string is present. Live Metrics streaming is enabled automatically; no portal-side configuration changes are required. If you are running outside Azure, ensure outbound access to the configured ingestion endpoint so the live stream can connect.

## Troubleshooting

- Ensure the connection string or instrumentation key environment variable is set before starting the app.
- Use `pip list` to confirm the expected OpenTelemetry packages are installed.
- If running behind a proxy, set the appropriate proxy variables so the exporter can reach Azure Monitor.
- To suppress the local warning about missing `azure_app_service` detector, set `OTEL_PYTHON_RESOURCE_DETECTORS=env,process` before launching `uvicorn`.
