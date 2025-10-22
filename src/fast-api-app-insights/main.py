"""FastAPI application instrumented for Azure Application Insights."""

import logging
import os
from contextlib import asynccontextmanager
from typing import AsyncIterator

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from telemetry import configure_telemetry

logger = logging.getLogger("fastapi-app")

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

    async with httpx.AsyncClient() as client:
        response = await client.get("https://httpbin.org/get", timeout=10)
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

    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", "8000")),
        reload=False,
    )
