"""Helpers to configure Azure Monitor telemetry exporters for FastAPI."""

import logging
import os
from typing import Optional

from azure.monitor.opentelemetry.exporter import (
    AzureMonitorLogExporter,
    AzureMonitorMetricExporter,
    AzureMonitorTraceExporter,
)
from fastapi import FastAPI
from opentelemetry import _logs, metrics, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased


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
    """Wire Azure Monitor exporters and FastAPI instrumentation on first call."""
    global _configured
    if _configured:
        return

    conn_str = _connection_string(connection_string)

    resource = Resource.create(
        {
            "service.name": os.getenv("OTEL_SERVICE_NAME", "fast-api-app"),
            "service.namespace": os.getenv("OTEL_SERVICE_NAMESPACE", "sample"),
            "service.instance.id": os.getenv("HOSTNAME", "local-instance"),
        }
    )

    tracer_provider = TracerProvider(
        resource=resource,
        sampler=TraceIdRatioBased(float(os.getenv("OTEL_TRACES_SAMPLER_RATIO", "1.0"))),
    )
    trace.set_tracer_provider(tracer_provider)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(
            AzureMonitorTraceExporter(connection_string=conn_str)
        )
    )

    FastAPIInstrumentor.instrument_app(app, tracer_provider=tracer_provider)
    RequestsInstrumentor().instrument(tracer_provider=tracer_provider)

    LoggingInstrumentor().instrument(set_logging_format=True)

    metric_exporter = AzureMonitorMetricExporter(
        connection_string=conn_str,
        enable_live_metrics=True,
    )
    metric_reader = PeriodicExportingMetricReader(metric_exporter)
    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)

    logger_provider = LoggerProvider(resource=resource)
    log_exporter = AzureMonitorLogExporter(connection_string=conn_str)
    logger_provider.add_log_record_processor(
        BatchLogRecordProcessor(log_exporter)
    )
    _logs.set_logger_provider(logger_provider)

    handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
    logging.getLogger().addHandler(handler)

    _configured = True
