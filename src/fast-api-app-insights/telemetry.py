"""Helpers to configure Azure Monitor telemetry for FastAPI using the distro."""

import logging
import os
import time
from typing import Optional

from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI, Request
from opentelemetry import metrics, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource

logger = logging.getLogger(__name__)

_configured = False
_meter = None
_request_counter = None
_request_duration = None
_failure_counter = None


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


def setup_metrics_middleware(app: FastAPI) -> None:
    """Add metrics tracking middleware to the FastAPI app."""
    global _request_counter, _request_duration, _failure_counter
    
    @app.middleware("http")
    async def metrics_middleware(request: Request, call_next):
        start_time = time.time()
        
        try:
            response = await call_next(request)
            duration = (time.time() - start_time) * 1000  # Convert to milliseconds
            
            # Record metrics with labels
            if _request_counter and _request_duration:
                attributes = {
                    "http.method": request.method,
                    "http.route": request.url.path,
                    "http.status_code": str(response.status_code),
                }
                
                _request_counter.add(1, attributes)
                _request_duration.record(duration, attributes)
                
                # Track failures (4xx and 5xx)
                if response.status_code >= 400 and _failure_counter:
                    _failure_counter.add(1, attributes)
            
            return response
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            
            # Record exception metrics
            if _failure_counter:
                attributes = {
                    "http.method": request.method,
                    "http.route": request.url.path,
                    "http.status_code": "500",
                }
                _failure_counter.add(1, attributes)
            
            logger.exception("Request processing failed")
            raise


def configure_telemetry(app: FastAPI, *, connection_string: Optional[str] = None) -> None:
    """Configure Azure Monitor telemetry using the distro package with full metrics support."""
    global _configured, _meter, _request_counter, _request_duration, _failure_counter
    if _configured:
        return

    conn_str = _connection_string(connection_string)
    
    # Get service name from environment or use default
    service_name = os.getenv("OTEL_SERVICE_NAME", "fast-api-app")
    
    logger.info(f"Configuring Azure Monitor telemetry for service: {service_name}")
    
    # Configure Azure Monitor with proper resource attributes
    resource = Resource.create({SERVICE_NAME: service_name})
    
    # Use the Azure Monitor distro for automatic instrumentation
    configure_azure_monitor(
        connection_string=conn_str,
        enable_live_metrics=True,
        resource=resource,
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
    
    logger.info("Azure Monitor configured successfully")
    
    # Explicitly instrument FastAPI for better performance metrics
    FastAPIInstrumentor.instrument_app(app)
    logger.info("FastAPI instrumentation applied")
    
    # Create custom metrics for detailed performance tracking
    _meter = metrics.get_meter(__name__, version="1.0.0")
    
    # Create standard HTTP server metrics matching Application Insights conventions
    _request_counter = _meter.create_counter(
        name="http.server.request.count",
        description="Total number of HTTP requests",
        unit="1",
    )
    
    _request_duration = _meter.create_histogram(
        name="http.server.request.duration",
        description="HTTP request duration in milliseconds",
        unit="ms",
    )
    
    _failure_counter = _meter.create_counter(
        name="http.server.request.failures",
        description="Total number of failed HTTP requests (4xx and 5xx)",
        unit="1",
    )
    
    logger.info("Custom performance metrics configured")

    _configured = True
