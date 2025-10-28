"""FastAPI application instrumented for Azure Application Insights."""

import logging
import os
from contextlib import asynccontextmanager
from typing import AsyncIterator

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from opentelemetry import trace

from telemetry import configure_telemetry, setup_metrics_middleware

logger = logging.getLogger("fastapi-app")
tracer = trace.get_tracer(__name__)

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Initialize telemetry once when the FastAPI app starts."""

    configure_telemetry(app)
    logger.info("Telemetry configured")
    yield


app = FastAPI(
    title="FastAPI + Application Insights Demo",
    description="""
    A demonstration FastAPI application instrumented with Azure Application Insights
    using OpenTelemetry for distributed tracing, metrics, and logging.
    
    ## Features
    
    * **Distributed Tracing**: All endpoints automatically traced with OpenTelemetry
    * **Live Metrics**: Real-time monitoring via Azure Application Insights
    * **Custom Spans**: Detailed operation tracking with attributes and events
    * **Exception Tracking**: Automatic error reporting and correlation
    * **External Dependencies**: HTTP calls tracked with full context propagation
    
    ## Endpoints Overview
    
    * **Root (/)**: Basic endpoint with external API call
    * **Health (/healthz)**: Simple health check probe
    * **Slow (/slow)**: Demonstrates multi-step processing with delays
    * **Chain (/chain)**: Shows sequential API call tracing
    * **Error (/error)**: Tests exception tracking and error spans
    """,
    version="1.0.0",
    contact={
        "name": "API Support",
        "email": "support@example.com",
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT",
    },
    lifespan=lifespan,
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc",  # ReDoc alternative documentation
    openapi_url="/openapi.json",  # OpenAPI spec endpoint
)

# Add metrics middleware before any requests are processed
setup_metrics_middleware(app)


@app.get(
    "/",
    summary="Root endpoint",
    description="Returns a demo payload after making an external HTTP call to httpbin.org for trace demonstration",
    response_description="JSON response with telemetry demo data",
    tags=["Demo"],
)
async def root(request: Request) -> JSONResponse:
    """Return demo payload after issuing an outbound HTTP call for trace data.
    
    This endpoint demonstrates:
    - Basic request handling
    - External API dependency tracking
    - Custom span creation with attributes
    - Distributed tracing context propagation
    """
    
    logger.info("Processing root endpoint request")
    
    httpbin_status = None
    error_message = None
    
    with tracer.start_as_current_span("fetch-external-data") as span:
        span.set_attribute("external.service", "httpbin.org")
        span.set_attribute("operation", "get-request")
        
        try:
            logger.info("Calling external API: httpbin.org/get")
            async with httpx.AsyncClient() as client:
                response = await client.get("https://httpbin.org/get", timeout=10)
                
            httpbin_status = response.status_code
            span.set_attribute("response.status", httpbin_status)
            logger.info(f"External API responded with status: {httpbin_status}")
        except Exception as e:
            error_message = str(e)
            span.set_attribute("error", True)
            span.set_attribute("error.message", error_message)
            logger.warning(f"External API call failed: {error_message}")
    
    logger.info("Returning response to client")
    return JSONResponse(
        {
            "message": "Telemetry demo",
            "client_host": request.client.host if request.client else None,
            "httpbin_status": httpbin_status,
            "httpbin_error": error_message if error_message else None,
        }
    )


@app.get(
    "/healthz",
    summary="Health check",
    description="Lightweight health probe endpoint for monitoring and load balancer checks",
    response_description="Health status object",
    tags=["Health"],
    responses={
        200: {
            "description": "Service is healthy",
            "content": {
                "application/json": {
                    "example": {"status": "ok"}
                }
            }
        }
    }
)
async def healthz() -> dict[str, str]:
    """Provide a lightweight health probe endpoint.
    
    Returns a simple status indicator without making any external calls,
    suitable for Kubernetes liveness/readiness probes or load balancer health checks.
    """

    logger.debug("Health check endpoint called")
    return {"status": "ok"}


@app.get(
    "/slow",
    summary="Slow processing endpoint",
    description="Simulates a slow operation (~0.8s) with multiple external API calls for performance testing",
    response_description="Results from slow operation",
    tags=["Demo", "Performance"],
    responses={
        200: {
            "description": "Successful slow operation",
            "content": {
                "application/json": {
                    "example": {
                        "message": "Slow operation complete",
                        "results": [
                            {"uuid": "550e8400-e29b-41d4-a716-446655440000"},
                            {"origin": "192.168.1.1"}
                        ],
                        "total_time": "~0.8s"
                    }
                }
            }
        }
    }
)
async def slow_endpoint():
    """Endpoint that simulates slow processing with multiple external calls.
    
    This endpoint demonstrates:
    - Long-running operations
    - Multiple sequential external API calls
    - Custom span creation for each operation step
    - Span events and attributes for detailed tracing
    - Performance monitoring and bottleneck identification
    """
    import asyncio
    
    logger.info("Starting slow endpoint processing")
    
    with tracer.start_as_current_span("slow-processing") as span:
        span.set_attribute("processing.type", "slow")
        span.set_attribute("expected.duration", "~0.8s")
        
        # Simulate some work
        logger.info("Step 1: Processing data...")
        await asyncio.sleep(0.5)
        
        # Make multiple external calls
        results = []
        errors = []
        async with httpx.AsyncClient() as client:
            with tracer.start_as_current_span("external-call-uuid") as call_span:
                call_span.set_attribute("call.endpoint", "uuid")
                try:
                    logger.info("Making external call to httpbin.org/uuid")
                    response1 = await client.get("https://httpbin.org/uuid", timeout=10)
                    data1 = response1.json()
                    results.append(data1)
                    call_span.set_attribute("response.status", response1.status_code)
                except Exception as e:
                    error_msg = f"UUID call failed: {str(e)}"
                    errors.append(error_msg)
                    call_span.set_attribute("error", True)
                    call_span.set_attribute("error.message", str(e))
                    logger.warning(error_msg)
            
            with tracer.start_as_current_span("external-call-ip") as call_span:
                call_span.set_attribute("call.endpoint", "ip")
                try:
                    logger.info("Making external call to httpbin.org/ip")
                    response2 = await client.get("https://httpbin.org/ip", timeout=10)
                    data2 = response2.json()
                    results.append(data2)
                    call_span.set_attribute("response.status", response2.status_code)
                except Exception as e:
                    error_msg = f"IP call failed: {str(e)}"
                    errors.append(error_msg)
                    call_span.set_attribute("error", True)
                    call_span.set_attribute("error.message", str(e))
                    logger.warning(error_msg)
        
        logger.info("Step 2: Aggregating results...")
        await asyncio.sleep(0.3)
        
        span.set_attribute("calls.completed", len(results))
        span.set_attribute("calls.failed", len(errors))
        span.add_event("Processing complete", {"result_count": len(results), "error_count": len(errors)})
    
    logger.info("Slow endpoint processing complete")
    return {
        "message": "Slow operation complete",
        "results": results,
        "errors": errors if errors else None,
        "total_time": "~0.8s"
    }


@app.get(
    "/error",
    summary="Error endpoint",
    description="Intentionally raises an exception to demonstrate error tracking and exception telemetry",
    response_description="This endpoint always raises an exception",
    tags=["Demo", "Testing"],
    responses={
        500: {
            "description": "Internal server error (expected behavior)",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "This is a test error to demonstrate exception tracking"
                    }
                }
            }
        }
    }
)
async def error_endpoint():
    """Endpoint that triggers an error for testing exception tracking.
    
    This endpoint demonstrates:
    - Exception handling and tracking
    - Error span status and recording
    - Correlation of errors in Application Insights
    - Failure blade population for monitoring
    
    **Note**: This endpoint always returns HTTP 500 by design.
    """
    logger.warning("Error endpoint called - will raise exception")
    
    with tracer.start_as_current_span("error-operation") as span:
        span.set_attribute("operation.type", "error-test")
        
        try:
            logger.error("About to raise ValueError for testing")
            raise ValueError("This is a test error to demonstrate exception tracking")
        except ValueError as e:
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
            logger.exception("Exception occurred in error endpoint")
            raise


@app.get(
    "/chain",
    summary="Chain operation endpoint",
    description="Makes multiple sequential API calls to demonstrate distributed tracing chains",
    response_description="Aggregated results from all chained API calls",
    tags=["Demo", "Tracing"],
    responses={
        200: {
            "description": "Successful chain operation",
            "content": {
                "application/json": {
                    "example": {
                        "message": "Chain operation complete",
                        "total_calls": 3,
                        "results": [
                            {"endpoint": "uuid", "data": {"uuid": "123"}},
                            {"endpoint": "user-agent", "data": {"user-agent": "python"}},
                            {"endpoint": "headers", "data": {"headers": {}}}
                        ]
                    }
                }
            }
        }
    }
)
async def chain_endpoint():
    """Endpoint that makes multiple sequential API calls to generate a trace chain.
    
    This endpoint demonstrates:
    - Sequential operation chains
    - Parent-child span relationships
    - Context propagation across multiple calls
    - Aggregation of distributed operations
    - End-to-end transaction visibility
    """
    logger.info("Starting chain endpoint processing")
    
    with tracer.start_as_current_span("chain-operation") as span:
        span.set_attribute("operation.type", "sequential-chain")
        
        results = []
        errors = []
        endpoints = ["uuid", "user-agent", "headers"]
        
        async with httpx.AsyncClient() as client:
            for idx, endpoint in enumerate(endpoints):
                with tracer.start_as_current_span(f"call-{endpoint}") as call_span:
                    call_span.set_attribute("call.index", idx)
                    call_span.set_attribute("call.endpoint", endpoint)
                    
                    try:
                        logger.info(f"Call {idx+1}/{len(endpoints)}: Fetching {endpoint}")
                        url = f"https://httpbin.org/{endpoint}"
                        response = await client.get(url, timeout=10)
                        data = response.json()
                        
                        call_span.set_attribute("response.status", response.status_code)
                        call_span.add_event(f"Received data from {endpoint}")
                        
                        results.append({"endpoint": endpoint, "data": data})
                    except Exception as e:
                        error_msg = f"Call to {endpoint} failed: {str(e)}"
                        errors.append(error_msg)
                        call_span.set_attribute("error", True)
                        call_span.set_attribute("error.message", str(e))
                        logger.warning(error_msg)
        
        span.set_attribute("chain.length", len(endpoints))
        span.set_attribute("calls.successful", len(results))
        span.set_attribute("calls.failed", len(errors))
        span.add_event("Chain processing completed", {"total_calls": len(results), "errors": len(errors)})
    
    logger.info(f"Chain endpoint complete with {len(results)} successful calls and {len(errors)} errors")
    return {
        "message": "Chain operation complete",
        "total_calls": len(results),
        "results": results,
        "errors": errors if errors else None,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", "8000")),
        reload=False,
    )
