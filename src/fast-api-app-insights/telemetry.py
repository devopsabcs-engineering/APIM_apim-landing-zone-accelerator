"""Helpers to configure Azure Monitor telemetry for FastAPI using the distro."""

import os
from typing import Optional

from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI
from opentelemetry import metrics
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor


_configured = False


def _connection_string(env_override: Optional[str] = None) -> str:
    """Resolve the Application Insights connection string or instrumentation key."""
    direct = env_override or os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if direct:
        return direct
    instrumentation_key = os.getenv("APPINSIGHTS_INSTRUMENTATIONKEY")
    if instrumentation_key:
        return f"InstrumentationKey={instrumentation_key}"
    raise RuntimeError(
        "Set APPLICATIONINSIGHTS_CONNECTION_STRING or APPINSIGHTS_INSTRUMENTATIONKEY"
    )


def configure_telemetry(app: FastAPI, *, connection_string: Optional[str] = None) -> None:
    """Configure Azure Monitor telemetry using the distro package with full metrics support."""
    global _configured
    if _configured:
        return

    conn_str = _connection_string(connection_string)
    
    # Use the Azure Monitor distro for automatic instrumentation
    configure_azure_monitor(
        connection_string=conn_str,
        enable_live_metrics=True,
        instrumentation_options={
            "azure_sdk": {"enabled": True},
            "django": {"enabled": False},
            "fastapi": {"enabled": True},
            "flask": {"enabled": False},
            "psycopg2": {"enabled": False},
            "requests": {"enabled": True},
            "urllib": {"enabled": True},
            "urllib3": {"enabled": True},
            "httpx": {"enabled": True},
        },
    )
    
    # Explicitly instrument FastAPI for better performance metrics
    FastAPIInstrumentor.instrument_app(app)
    
    # Create custom metrics for detailed performance tracking
    meter = metrics.get_meter(__name__)
    
    # Create custom counters and histograms for performance insights
    request_counter = meter.create_counter(
        name="app.requests.total",
        description="Total number of requests",
        unit="1",
    )
    
    request_duration = meter.create_histogram(
        name="app.request.duration",
        description="Request duration in milliseconds",
        unit="ms",
    )
    
    # Add middleware to track request metrics
    @app.middleware("http")
    async def metrics_middleware(request, call_next):
        import time
        
        start_time = time.time()
        response = await call_next(request)
        duration = (time.time() - start_time) * 1000  # Convert to milliseconds
        
        # Record metrics with labels
        request_counter.add(
            1,
            {
                "method": request.method,
                "endpoint": request.url.path,
                "status": response.status_code,
            }
        )
        
        request_duration.record(
            duration,
            {
                "method": request.method,
                "endpoint": request.url.path,
                "status": response.status_code,
            }
        )
        
        return response

    _configured = True
