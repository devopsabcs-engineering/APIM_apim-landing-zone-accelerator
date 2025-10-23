"""Helpers to configure Azure Monitor telemetry for FastAPI using the distro."""

import os
from typing import Optional

from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI


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
    """Configure Azure Monitor telemetry using the distro package."""
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

    _configured = True
