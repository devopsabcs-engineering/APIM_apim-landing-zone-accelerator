import logging
import time
from platform import python_version
from typing import Optional

import requests
from azure.monitor.opentelemetry import configure_azure_monitor
from flask import Flask, redirect, render_template, request, session, url_for
from flask_session import Session
from opentelemetry import metrics, trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk._logs import LoggingHandler
from opentelemetry.sdk.resources import Resource
from opentelemetry.trace import Status, StatusCode
from requests import RequestException

import app_config
from msal_auth import MsalAuth

#__version__ = "1.2.3"  # The version of this sample, for troubleshooting purpose

app = Flask(__name__)
app.config.from_object(app_config)
assert app.config["REDIRECT_PATH"] != "/", "REDIRECT_PATH must not be /"
# get the version from config
__version__ = app.config.get("VERSION", "1.2.3")
__python_version__ = python_version()
Session(app)

telemetry_logger = logging.getLogger("msal_python_soln.telemetry")


def _resolve_log_level(level_name: Optional[str], fallback: int = logging.INFO) -> int:
    if not level_name:
        return fallback
    candidate = getattr(logging, str(level_name).upper(), None)
    if isinstance(candidate, int):
        return candidate
    try:
        numeric_level = int(level_name)
        if numeric_level >= 0:
            return numeric_level
    except (TypeError, ValueError):
        return fallback
    return fallback


def _configure_observability() -> None:
    if app.config.get("_OTEL_INSTRUMENTED"):
        return

    default_log_level = _resolve_log_level(app.config.get("LOGGING_LEVEL_DEFAULT"), logging.INFO)
    logging.basicConfig(level=default_log_level)
    telemetry_logger.setLevel(default_log_level)

    if not app.config.get("ENABLE_OPENTELEMETRY", True):
        telemetry_logger.info("OpenTelemetry explicitly disabled via configuration")
        app.config["_OTEL_INSTRUMENTED"] = False
        return

    resource_attributes = {
        "service.name": app.config.get("SERVICE_NAME", "msal-python-soln"),
        "service.version": __version__,
        "deployment.environment": app.config.get("DEPLOYMENT_ENVIRONMENT", "local"),
    }

    if app.config.get("APPLICATIONINSIGHTS_CLOUD_ROLE"):
        resource_attributes["service.cloud_role"] = app.config["APPLICATIONINSIGHTS_CLOUD_ROLE"]
    if app.config.get("APPLICATIONINSIGHTS_CLOUD_ROLE_INSTANCE"):
        resource_attributes["service.cloud_role_instance"] = app.config[
            "APPLICATIONINSIGHTS_CLOUD_ROLE_INSTANCE"
        ]

    resource = Resource.create(resource_attributes)
    connection_string = app.config.get("APPLICATIONINSIGHTS_CONNECTION_STRING")

    try:
        configure_azure_monitor(
            connection_string=connection_string,
            resource=resource,
            enable_live_metrics=app.config.get("ENABLE_LIVE_METRICS", False),
        )
        telemetry_logger.info("Azure Monitor exporter configured")
    except ValueError:
        telemetry_logger.warning(
            "Application Insights connection string missing; telemetry exporters not configured"
        )

    app_insights_log_level = _resolve_log_level(
        app.config.get("LOGGING_APPLICATIONINSIGHTS_LEVEL"),
        default_log_level,
    )

    if not any(isinstance(handler, LoggingHandler) for handler in telemetry_logger.handlers):
        telemetry_logger.addHandler(LoggingHandler(level=app_insights_log_level))

    FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()

    app.config["_OTEL_INSTRUMENTED"] = True


_configure_observability()

tracer = trace.get_tracer("msal_python_soln.web")
meter = metrics.get_meter("msal_python_soln.web")

login_attempt_counter = meter.create_counter(
    "auth_login_attempts", description="Number of interactive login attempts", unit="1"
)
login_failure_counter = meter.create_counter(
    "auth_login_failures", description="Number of failed login attempts", unit="1"
)
downstream_api_counter = meter.create_counter(
    "downstream_api_requests", description="Downstream API requests", unit="1"
)
downstream_api_failure_counter = meter.create_counter(
    "downstream_api_failures", description="Failed downstream API requests", unit="1"
)
downstream_api_latency = meter.create_histogram(
    "downstream_api_latency_ms",
    description="Latency of downstream API calls",
    unit="ms",
)

# This section is needed for url_for("foo", _external=True) to automatically
# generate http scheme when this sample is running on localhost,
# and to generate https scheme when it is deployed behind reversed proxy.
# See also https://flask.palletsprojects.com/en/2.2.x/deploying/proxy_fix/
from werkzeug.middleware.proxy_fix import ProxyFix
app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

app.jinja_env.globals.update(Auth=MsalAuth)  # Useful in template for B2C
auth = MsalAuth(
    session=session,
    authority=app.config["AUTHORITY"],
    client_id=app.config["CLIENT_ID"],
    client_credential=app.config["CLIENT_SECRET"],
)


@app.route("/login")
def login():
    login_attempt_counter.add(1, {"auth.flow": "interactive"})
    telemetry_logger.info("Rendering login prompt")
    return render_template("login.html", version=__version__, **auth.log_in(
        scopes=app_config.SCOPE, # Have user consent to scopes during log-in
        redirect_uri=url_for("auth_response", _external=True), # Optional. If present, this absolute URL must match your app's redirect_uri registered in Azure Portal
        prompt="select_account",  # Optional. More values defined in  https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest
        ), pythonVersion=__python_version__)


@app.route(app_config.REDIRECT_PATH)
def auth_response():
    with tracer.start_as_current_span("auth_response") as span:
        span.set_attribute("auth.flow", "interactive")
        result = auth.complete_log_in(request.args)
        if "error" in result:
            login_failure_counter.add(1, {"auth.flow": "interactive"})
            span.record_exception(Exception(result.get("error_description", "login_error")))
            span.set_status(Status(StatusCode.ERROR, result.get("error", "login_error")))
            telemetry_logger.warning("Login failed: %s", result.get("error"))
            return render_template("auth_error.html", result=result)

        span.set_status(Status(StatusCode.OK))
        telemetry_logger.info("Login completed")
        return redirect(url_for("index"))


@app.route("/logout")
def logout():
    telemetry_logger.info("User initiated logout")
    return redirect(auth.log_out(url_for("index", _external=True)))


@app.route("/")
def index():
    if not (app.config["CLIENT_ID"] and app.config["CLIENT_SECRET"]):
        # This check is not strictly necessary.
        # You can remove this check from your production code.
        telemetry_logger.error("Configuration missing client credentials")
        return render_template('config_error.html')
    if not auth.get_user():
        telemetry_logger.info("Anonymous user redirect to login")
        return redirect(url_for("login"))
    telemetry_logger.info("Rendering index for authenticated user", extra={"user.authenticated": True})
    return render_template('index.html', user=auth.get_user(), version=__version__, pythonVersion=__python_version__)


@app.route("/call_downstream_api")
def call_downstream_api():
    with tracer.start_as_current_span("call_downstream_api") as span:
        span.set_attribute("downstream.scope_count", len(app_config.SCOPE))
        span.set_attribute("downstream.endpoint", app_config.ENDPOINT)
        request_attributes = {"downstream.endpoint": app_config.ENDPOINT}

        token = auth.get_token_for_user(app_config.SCOPE)
        if "error" in token:
            span.set_status(Status(StatusCode.ERROR, token.get("error", "token_error")))
            login_failure_counter.add(1, {"auth.flow": "acquire_token"})
            downstream_api_failure_counter.add(1, {**request_attributes, "failure.stage": "token"})
            telemetry_logger.warning("Failed to acquire token: %s", token.get("error"))
            return redirect(url_for("login"))

        bearer = token.get('access_token', '')
        headers = {'Authorization': 'Bearer ' + bearer}

        start_time = time.perf_counter()
        try:
            response = requests.get(
                app_config.ENDPOINT,
                headers=headers,
                timeout=30,
            )
            response.raise_for_status()
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            downstream_api_counter.add(1, request_attributes)
            downstream_api_latency.record(elapsed_ms, request_attributes)
            api_result = response.json()
            span.set_status(Status(StatusCode.OK))
            telemetry_logger.info(
                "Downstream API call succeeded", extra={"endpoint": app_config.ENDPOINT, "latency_ms": round(elapsed_ms, 2)}
            )
        except RequestException as exc:
            downstream_api_failure_counter.add(1, {**request_attributes, "failure.stage": "request"})
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, "downstream_request_failed"))
            telemetry_logger.exception("Downstream API call failed")
            api_result = {"error": "Failed to call downstream API", "detail": str(exc)}
        except ValueError as exc:
            downstream_api_failure_counter.add(1, {**request_attributes, "failure.stage": "payload"})
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, "downstream_payload_error"))
            telemetry_logger.exception("Failed to parse downstream API response")
            api_result = {"error": "Invalid JSON payload from downstream API", "detail": str(exc)}

        return render_template('display.html', result=api_result, bearerToken=bearer, scopes=app_config.SCOPE, endpoint=app_config.ENDPOINT)


if __name__ == "__main__":
    app.run()
