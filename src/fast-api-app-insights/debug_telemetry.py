"""Debug script to check what telemetry is being sent."""
import os
import sys

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

from dotenv import load_dotenv
load_dotenv()

# Check package versions
print("=" * 60)
print("Package Versions:")
print("=" * 60)

try:
    import azure.monitor.opentelemetry
    print(f"azure-monitor-opentelemetry: {azure.monitor.opentelemetry.__version__}")
except Exception as e:
    print(f"azure-monitor-opentelemetry: ERROR - {e}")

try:
    import opentelemetry
    print(f"opentelemetry-api: {opentelemetry.__version__}")
except Exception as e:
    print(f"opentelemetry-api: ERROR - {e}")

try:
    from opentelemetry.instrumentation.fastapi import __version__ as fastapi_instr_version
    print(f"opentelemetry-instrumentation-fastapi: {fastapi_instr_version}")
except Exception as e:
    print(f"opentelemetry-instrumentation-fastapi: ERROR - {e}")

print()
print("=" * 60)
print("Environment Variables:")
print("=" * 60)

conn_str = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
if conn_str:
    # Mask the key
    if "InstrumentationKey=" in conn_str:
        parts = conn_str.split(";")
        for part in parts:
            if "InstrumentationKey=" in part:
                print(f"✓ APPLICATIONINSIGHTS_CONNECTION_STRING: InstrumentationKey=***")
            elif part:
                print(f"  {part}")
else:
    print("✗ APPLICATIONINSIGHTS_CONNECTION_STRING: NOT SET")

print()
print("Other OTEL settings:")
for key in ["OTEL_SERVICE_NAME", "OTEL_METRIC_EXPORT_INTERVAL", "OTEL_SEMCONV_STABILITY_OPT_IN"]:
    value = os.getenv(key)
    print(f"  {key}: {value if value else 'not set'}")

print()
print("=" * 60)
print("Testing OpenTelemetry Setup:")
print("=" * 60)

# Try to configure and create a test span
try:
    from azure.monitor.opentelemetry import configure_azure_monitor
    from opentelemetry import trace
    from opentelemetry.sdk.resources import SERVICE_NAME, Resource
    
    resource = Resource.create({SERVICE_NAME: "test-app"})
    
    configure_azure_monitor(
        connection_string=conn_str,
        resource=resource,
    )
    
    print("✓ Azure Monitor configured successfully")
    
    # Create a test span
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("test-span") as span:
        span.set_attribute("test.attribute", "test-value")
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.url", "http://test.local/")
        span.set_attribute("http.status_code", 200)
        print(f"✓ Created test span: {span.name}")
        print(f"  Span ID: {format(span.get_span_context().span_id, '016x')}")
        print(f"  Trace ID: {format(span.get_span_context().trace_id, '032x')}")
        print(f"  Is recording: {span.is_recording()}")
        
    print("\n✓ Test span completed and should be exported to Application Insights")
    print("  Check Transaction Search in 30-60 seconds for a span named 'test-span'")
    
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()

print()
print("=" * 60)
print("Summary:")
print("=" * 60)
print("If you see the test span in Application Insights but not requests,")
print("the issue is with how FastAPI instrumentation creates spans.")
print()
print("The FastAPI instrumentation should create spans with:")
print("  - SpanKind.SERVER")
print("  - http.method, http.target, http.status_code attributes")
print("  - These are what Application Insights uses to classify as 'requests'")
print("=" * 60)
