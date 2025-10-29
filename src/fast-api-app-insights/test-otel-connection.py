"""Simple test to verify OpenTelemetry is sending data to Application Insights."""

import os
import time
from dotenv import load_dotenv
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics

# Load environment
load_dotenv()

# Configure Azure Monitor
connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
if not connection_string:
    print("ERROR: APPLICATIONINSIGHTS_CONNECTION_STRING not set")
    exit(1)

print(f"Configuring with connection string (first 50 chars): {connection_string[:50]}...")

configure_azure_monitor(
    connection_string=connection_string,
    enable_live_metrics=True,
)

print("✓ Azure Monitor configured")

# Get tracer and create a span
tracer = trace.get_tracer(__name__)

print("\nSending test telemetry...")

# Create a test span (trace)
with tracer.start_as_current_span("test-operation") as span:
    span.set_attribute("test.attribute", "test-value")
    span.add_event("test-event", {"event.data": "test"})
    print("  ✓ Sent trace span")
    time.sleep(0.1)

# Create test metrics
meter = metrics.get_meter(__name__)
test_counter = meter.create_counter("test.counter", description="Test counter")
test_counter.add(1, {"test.label": "test-value"})
print("  ✓ Sent metric")

# Wait a bit for data to be sent
print("\nWaiting 5 seconds for data to be exported...")
time.sleep(5)

print("\n✅ Test complete!")
print("\nCheck Application Insights:")
print("  1. Live Metrics - should show this test data immediately")
print("  2. Transaction Search - look for 'test-operation' span")
print("  3. Metrics - look for 'test.counter' metric")
print("\nIf you don't see data, there may be a network/firewall issue.")
