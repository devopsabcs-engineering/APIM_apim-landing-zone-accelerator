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

from telemetry import configure_telemetry

logger = logging.getLogger("fastapi-app")
tracer = trace.get_tracer(__name__)

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Initialize telemetry once when the FastAPI app starts."""

    configure_telemetry(app)
    logger.info("Telemetry configured")
    yield


app = FastAPI(title="FastAPI + Application Insights", lifespan=lifespan)


@app.get("/")
async def root(request: Request) -> JSONResponse:
    """Return demo payload after issuing an outbound HTTP call for trace data."""
    
    logger.info("Processing root endpoint request")
    
    with tracer.start_as_current_span("fetch-external-data") as span:
        span.set_attribute("external.service", "httpbin.org")
        span.set_attribute("operation", "get-request")
        
        logger.info("Calling external API: httpbin.org/get")
        async with httpx.AsyncClient() as client:
            response = await client.get("https://httpbin.org/get", timeout=10)
            
        span.set_attribute("response.status", response.status_code)
        logger.info(f"External API responded with status: {response.status_code}")
    
    logger.info("Returning response to client")
    return JSONResponse(
        {
            "message": "Telemetry demo",
            "client_host": request.client.host if request.client else None,
            "httpbin_status": response.status_code,
        }
    )


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    """Provide a lightweight health probe endpoint."""

    logger.debug("Health check endpoint called")
    return {"status": "ok"}


@app.get("/slow")
async def slow_endpoint():
    """Endpoint that simulates slow processing with multiple external calls."""
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
        async with httpx.AsyncClient() as client:
            with tracer.start_as_current_span("external-call-uuid") as call_span:
                call_span.set_attribute("call.endpoint", "uuid")
                logger.info("Making external call to httpbin.org/uuid")
                response1 = await client.get("https://httpbin.org/uuid", timeout=10)
                data1 = response1.json()
                results.append(data1)
                call_span.set_attribute("response.status", response1.status_code)
            
            with tracer.start_as_current_span("external-call-ip") as call_span:
                call_span.set_attribute("call.endpoint", "ip")
                logger.info("Making external call to httpbin.org/ip")
                response2 = await client.get("https://httpbin.org/ip", timeout=10)
                data2 = response2.json()
                results.append(data2)
                call_span.set_attribute("response.status", response2.status_code)
        
        logger.info("Step 2: Aggregating results...")
        await asyncio.sleep(0.3)
        
        span.set_attribute("calls.completed", 2)
        span.add_event("Processing complete", {"result_count": len(results)})
    
    logger.info("Slow endpoint processing complete")
    return {
        "message": "Slow operation complete",
        "results": results,
        "total_time": "~0.8s"
    }


@app.get("/error")
async def error_endpoint():
    """Endpoint that triggers an error for testing exception tracking."""
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


@app.get("/chain")
async def chain_endpoint():
    """Endpoint that makes multiple sequential API calls to generate a trace chain."""
    logger.info("Starting chain endpoint processing")
    
    with tracer.start_as_current_span("chain-operation") as span:
        span.set_attribute("operation.type", "sequential-chain")
        
        results = []
        endpoints = ["uuid", "user-agent", "headers"]
        
        async with httpx.AsyncClient() as client:
            for idx, endpoint in enumerate(endpoints):
                with tracer.start_as_current_span(f"call-{endpoint}") as call_span:
                    call_span.set_attribute("call.index", idx)
                    call_span.set_attribute("call.endpoint", endpoint)
                    
                    logger.info(f"Call {idx+1}/{len(endpoints)}: Fetching {endpoint}")
                    url = f"https://httpbin.org/{endpoint}"
                    response = await client.get(url, timeout=10)
                    data = response.json()
                    
                    call_span.set_attribute("response.status", response.status_code)
                    call_span.add_event(f"Received data from {endpoint}")
                    
                    results.append({"endpoint": endpoint, "data": data})
        
        span.set_attribute("chain.length", len(endpoints))
        span.add_event("All calls completed", {"total_calls": len(results)})
    
    logger.info(f"Chain endpoint complete with {len(results)} calls")
    return {
        "message": "Chain operation complete",
        "total_calls": len(results),
        "results": results
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", "8000")),
        reload=False,
    )
