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
from opentelemetry.semconv.trace import SpanAttributes
from opentelemetry.trace import SpanKind

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


def _server_request_hook(span, scope):
    """Hook to ensure spans have proper attributes for Application Insights request telemetry."""
    if span and span.is_recording():
        # CRITICAL: Ensure this is marked as a SERVER span
        # Application Insights maps SERVER spans to "request" telemetry type
        span._kind = SpanKind.SERVER
        
        # Add ALL HTTP semantic convention attributes that Application Insights expects
        if scope:
            # Extract request info from ASGI scope
            path = scope.get("path", "")
            method = scope.get("method", "")
            query_string = scope.get("query_string", b"").decode("utf-8")
            scheme = scope.get("scheme", "http")
            server = scope.get("server", ("localhost", 8000))
            
            # Build full URL
            host = f"{server[0]}:{server[1]}" if server else "localhost:8000"
            url = f"{scheme}://{host}{path}"
            if query_string:
                url += f"?{query_string}"
            
            # Set REQUIRED HTTP semantic convention attributes
            # These are what Application Insights uses to classify spans as requests
            span.set_attribute(SpanAttributes.HTTP_METHOD, method)
            span.set_attribute(SpanAttributes.HTTP_TARGET, path)
            span.set_attribute(SpanAttributes.HTTP_URL, url)
            span.set_attribute(SpanAttributes.HTTP_SCHEME, scheme)
            span.set_attribute(SpanAttributes.HTTP_HOST, host)
            span.set_attribute(SpanAttributes.HTTP_FLAVOR, "1.1")
            
            # Set server address attributes
            span.set_attribute(SpanAttributes.NET_HOST_NAME, server[0] if server else "localhost")
            span.set_attribute(SpanAttributes.NET_HOST_PORT, server[1] if server and len(server) > 1 else 8000)
                
        logger.debug(f"✅ Server request hook applied to span: {span.name} (kind={span._kind})")


def _server_response_hook(span, message):
    """Hook to capture response status code."""
    if span and span.is_recording() and message:
        status_code = message.get("status", 200)
        span.set_attribute(SpanAttributes.HTTP_STATUS_CODE, status_code)
        logger.debug(f"✅ Server response hook applied: status={status_code}")


def configure_telemetry(app: FastAPI, *, connection_string: Optional[str] = None) -> None:
    """Configure Azure Monitor telemetry using the distro package with full metrics support."""
    global _configured, _meter, _request_counter, _request_duration, _failure_counter
    if _configured:
        return

    conn_str = _connection_string(connection_string)
    
    # Get service name from environment or use default
    service_name = os.getenv("OTEL_SERVICE_NAME", "fast-api-app")
    
    logger.info("=" * 70)
    logger.info(f"Configuring Azure Monitor telemetry for service: {service_name}")
    logger.info(f"Live Metrics Enabled: True")
    logger.info(f"Connection String configured: Yes")
    logger.info("=" * 70)
    
    # Configure Azure Monitor with proper resource attributes
    resource = Resource.create({
        SERVICE_NAME: service_name,
        "service.version": "1.0.0",
        "deployment.environment": os.getenv("OTEL_RESOURCE_ATTRIBUTES", "development")
    })
    
    # Use the Azure Monitor distro for automatic instrumentation
    # This configures traces, metrics, and logs exporters automatically
    # IMPORTANT: We disable FastAPI auto-instrumentation here because we'll do it manually below
    # to have full control over span attributes and hooks
    configure_azure_monitor(
        connection_string=conn_str,
        enable_live_metrics=True,
        resource=resource,
        # Disable FastAPI auto-instrumentation - we'll do it manually for full control
        instrumentation_options={
            "azure_sdk": {"enabled": True},
            "django": {"enabled": False},
            "fastapi": {"enabled": False},  # DISABLED - manual instrumentation below
            "flask": {"enabled": False},
            "psycopg2": {"enabled": False},
            "requests": {"enabled": True},
            "urllib": {"enabled": True},
            "urllib3": {"enabled": True},
            "httpx": {"enabled": True},
        },
    )
    
    logger.info("Azure Monitor configured successfully with FastAPI instrumentation enabled")
    logger.info(f"Connection to: {conn_str.split(';')[1] if ';' in conn_str else 'default endpoint'}")
    logger.info(f"Live Endpoint: {conn_str.split(';')[2] if ';' in conn_str and conn_str.count(';') > 2 else 'default'}")
    logger.info("Live Metrics stream should be active - check Azure Portal > Live Metrics")
    logger.info("=" * 70)
    
    # CRITICAL: Manually instrument FastAPI with proper configuration
    # This ensures HTTP server spans are created with the correct attributes for Application Insights
    # We use hooks to inject ALL required HTTP semantic convention attributes
    try:
        # Configure the instrumentor with hooks to ensure proper span attributes
        FastAPIInstrumentor().instrument_app(
            app,
            server_request_hook=_server_request_hook,
            client_response_hook=_server_response_hook,
            excluded_urls=None,
        )
        logger.info("🎯 FastAPI application instrumented with custom request/response hooks")
        logger.info("🎯 HTTP server spans will have SpanKind.SERVER + full HTTP attributes")
        logger.info("🎯 Application Insights should classify these as 'REQUEST' telemetry type")
        logger.info("=" * 70)
    except Exception as e:
        logger.error(f"❌ Failed to instrument FastAPI: {e}")
        raise
    
    # Create custom metrics for additional performance tracking
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
    logger.info("Telemetry configuration complete - request data will be sent to Application Insights")

    _configured = True
