"""Alternative telemetry configuration using direct TelemetryClient."""

import logging
import os
import time
from typing import Optional

from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI, Request, Response
from opentelemetry import trace
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

_configured = False
_tracer = None


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


class RequestTelemetryMiddleware(BaseHTTPMiddleware):
    """Middleware that creates proper request telemetry using OpenTelemetry."""
    
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # Create a SERVER span with all required attributes
        with _tracer.start_as_current_span(
            f"{request.method} {request.url.path}",
            kind=trace.SpanKind.SERVER,
        ) as span:
            # Set ALL HTTP semantic convention attributes
            span.set_attribute("http.method", request.method)
            span.set_attribute("http.url", str(request.url))
            span.set_attribute("http.target", request.url.path)
            span.set_attribute("http.scheme", request.url.scheme)
            span.set_attribute("http.host", request.url.netloc or f"{request.client.host}:{request.url.port or 8000}")
            span.set_attribute("http.flavor", "1.1")
            span.set_attribute("http.user_agent", request.headers.get("user-agent", ""))
            span.set_attribute("net.host.name", request.client.host if request.client else "localhost")
            span.set_attribute("net.host.port", request.url.port or 8000)
            
            # Add request-specific attributes
            span.set_attribute("http.route", request.url.path)
            span.set_attribute("http.server_name", "fast-api-app-insights")
            
            try:
                response = await call_next(request)
                duration_ms = (time.time() - start_time) * 1000
                
                # Set response attributes
                span.set_attribute("http.status_code", response.status_code)
                span.set_attribute("http.response.duration_ms", duration_ms)
                
                # Set success/failure
                if response.status_code >= 400:
                    span.set_status(trace.Status(trace.StatusCode.ERROR))
                else:
                    span.set_status(trace.Status(trace.StatusCode.OK))
                
                logger.info(f"✅ Request: {request.method} {request.url.path} -> {response.status_code} ({duration_ms:.2f}ms)")
                
                return response
                
            except Exception as e:
                duration_ms = (time.time() - start_time) * 1000
                
                # Record exception in span
                span.set_attribute("http.status_code", 500)
                span.set_attribute("http.response.duration_ms", duration_ms)
                span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
                span.record_exception(e)
                
                logger.exception(f"❌ Request failed: {request.method} {request.url.path}")
                raise


def configure_telemetry(app: FastAPI, *, connection_string: Optional[str] = None, add_middleware: bool = True) -> None:
    """Configure Azure Monitor telemetry with custom request tracking."""
    global _configured, _tracer
    if _configured:
        return

    conn_str = _connection_string(connection_string)
    service_name = os.getenv("OTEL_SERVICE_NAME", "fast-api-app")
    
    logger.info("=" * 70)
    logger.info(f"🔧 Configuring Azure Monitor with CUSTOM request middleware")
    logger.info(f"Service: {service_name}")
    logger.info("=" * 70)
    
    # Configure Azure Monitor with NO automatic instrumentation
    resource = Resource.create({
        SERVICE_NAME: service_name,
        "service.version": "1.0.0",
        "deployment.environment": os.getenv("OTEL_RESOURCE_ATTRIBUTES", "development")
    })
    
    configure_azure_monitor(
        connection_string=conn_str,
        enable_live_metrics=True,
        resource=resource,
        # Disable ALL automatic instrumentation - we'll do it manually
        instrumentation_options={
            "azure_sdk": {"enabled": False},
            "django": {"enabled": False},
            "fastapi": {"enabled": False},
            "flask": {"enabled": False},
            "psycopg2": {"enabled": False},
            "requests": {"enabled": True},  # Keep this for httpx dependencies
            "urllib": {"enabled": True},
            "urllib3": {"enabled": True},
            "httpx": {"enabled": True},
        },
    )
    
    logger.info("✅ Azure Monitor configured")
    logger.info("✅ Live Metrics enabled")
    
    # Get the tracer for manual span creation
    _tracer = trace.get_tracer(__name__)
    
    # Add middleware only if requested (not during lifespan)
    if add_middleware:
        app.add_middleware(RequestTelemetryMiddleware)
        logger.info("✅ Custom request telemetry middleware added")
    
    logger.info("✅ All HTTP requests will be tracked as SERVER spans with full attributes")
    logger.info("=" * 70)
    
    _configured = True
