"""Locust load test for FastAPI Application Insights demo.

Usage:
    # Local testing
    locust --host=http://localhost:8000

    # Azure testing
    locust --host=https://fast-api-app-insights-001.azurewebsites.net

    # Headless mode with specific users and duration
    locust --host=http://localhost:8000 --users 10 --spawn-rate 2 --run-time 60s --headless

    # Web UI mode (default)
    locust --host=http://localhost:8000
    # Then open http://localhost:8089
"""

import random
from locust import HttpUser, task, between, events
import logging

logger = logging.getLogger(__name__)


class FastAPIUser(HttpUser):
    """Simulates a user interacting with the FastAPI application."""
    
    # Wait between 1 and 3 seconds between tasks
    wait_time = between(1, 3)
    
    @task(10)
    def get_root(self):
        """Test the root endpoint - highest weight (most frequent)."""
        with self.client.get("/", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(5)
    def get_healthz(self):
        """Test the health check endpoint - medium weight."""
        with self.client.get("/healthz", catch_response=True) as response:
            if response.status_code == 200 and response.json().get("status") == "ok":
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")
    
    @task(3)
    def get_slow(self):
        """Test the slow endpoint - lower weight (resource intensive)."""
        with self.client.get("/slow", catch_response=True, timeout=15) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Slow endpoint failed: {response.status_code}")
    
    @task(3)
    def get_chain(self):
        """Test the chain endpoint - lower weight (makes multiple external calls)."""
        with self.client.get("/chain", catch_response=True, timeout=20) as response:
            if response.status_code == 200:
                data = response.json()
                if data.get("total_calls") == 3:
                    response.success()
                else:
                    response.failure(f"Expected 3 calls, got {data.get('total_calls')}")
            else:
                response.failure(f"Chain endpoint failed: {response.status_code}")
    
    @task(1)
    def get_error(self):
        """Test the error endpoint - lowest weight (intentionally fails)."""
        with self.client.get("/error", catch_response=True) as response:
            # We expect a 500 error, so treat it as success for load testing
            if response.status_code == 500:
                response.success()
                logger.debug("Error endpoint returned expected 500 status")
            else:
                response.failure(f"Expected 500, got {response.status_code}")
    
    def on_start(self):
        """Called when a simulated user starts."""
        logger.info(f"User started - targeting {self.host}")
        # Optionally call healthz to "warm up" the user
        self.client.get("/healthz")


class SpikeUser(HttpUser):
    """Simulates spike traffic patterns - call only root and health endpoints rapidly."""
    
    wait_time = between(0.1, 0.5)  # Very short wait time for spike testing
    
    @task(8)
    def rapid_root(self):
        """Rapidly hit the root endpoint."""
        self.client.get("/", name="/[spike]")
    
    @task(2)
    def rapid_health(self):
        """Rapidly hit the health endpoint."""
        self.client.get("/healthz", name="/healthz[spike]")


class HeavyUser(HttpUser):
    """Simulates heavy users that call resource-intensive endpoints."""
    
    wait_time = between(2, 5)
    
    @task(5)
    def heavy_slow(self):
        """Call the slow endpoint frequently."""
        self.client.get("/slow", timeout=15, name="/slow[heavy]")
    
    @task(5)
    def heavy_chain(self):
        """Call the chain endpoint frequently."""
        self.client.get("/chain", timeout=20, name="/chain[heavy]")


# Event hooks for custom reporting
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts."""
    logger.info(f"Load test starting against {environment.host}")
    print(f"\n{'='*60}")
    print(f"Load Test Starting")
    print(f"Target: {environment.host}")
    print(f"{'='*60}\n")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops."""
    logger.info("Load test completed")
    print(f"\n{'='*60}")
    print(f"Load Test Complete")
    print(f"Check Application Insights for telemetry data:")
    print(f"  - Live Metrics")
    print(f"  - Transaction Search")
    print(f"  - Performance Blade")
    print(f"  - Application Map")
    print(f"{'='*60}\n")


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, context, **kwargs):
    """Log slow requests."""
    if response_time > 5000:  # Log requests slower than 5 seconds
        logger.warning(
            f"Slow request detected: {request_type} {name} took {response_time:.0f}ms"
        )
