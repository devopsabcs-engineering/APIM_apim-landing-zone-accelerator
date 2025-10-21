"""Minimal MSAL-based auth helper providing the interface expected by the app."""
from __future__ import annotations

import logging
from typing import Any, Dict, Mapping, MutableMapping, Optional, Sequence
from urllib.parse import quote

import msal

_logger = logging.getLogger("msal_python_soln.auth")


class MsalAuth:
    """MSAL wrapper that mimics the old identity.web.Auth surface."""

    def __init__(
        self,
        *,
        session: MutableMapping[str, Any],
        authority: str,
        client_id: str,
        client_credential: Optional[str],
        cache_session_key: str = "msal.cache",
        flow_session_key: str = "msal.flow",
        user_session_key: str = "msal.user",
    ) -> None:
        self._session = session
        self._authority = authority.rstrip("/")
        self._client_id = client_id
        self._client_credential = client_credential
        self._cache_session_key = cache_session_key
        self._flow_session_key = flow_session_key
        self._user_session_key = user_session_key

    # Flask's session behaves like a mutable mapping, but templates sometimes use
    # a plain dict, so we treat the mapping defensively.
    def _set_session_value(self, key: str, value: Any) -> None:
        if hasattr(self._session, "__setitem__"):
            self._session[key] = value

    def _pop_session_value(self, key: str) -> Any:
        if hasattr(self._session, "pop"):
            return self._session.pop(key, None)
        return None

    def _get_session_value(self, key: str) -> Any:
        if hasattr(self._session, "get"):
            return self._session.get(key)
        return None

    def _load_cache(self) -> msal.SerializableTokenCache:
        cache = msal.SerializableTokenCache()
        serialized = self._get_session_value(self._cache_session_key)
        if serialized:
            try:
                cache.deserialize(serialized)
            except ValueError:
                _logger.warning("Ignoring invalid token cache payload")
        return cache

    def _save_cache(self, cache: msal.SerializableTokenCache) -> None:
        if cache.has_state_changed:
            self._set_session_value(self._cache_session_key, cache.serialize())

    def _build_app(
        self,
        *,
        cache: Optional[msal.TokenCache] = None,
        authority: Optional[str] = None,
    ) -> msal.ConfidentialClientApplication:
        return msal.ConfidentialClientApplication(
            self._client_id,
            authority=authority or self._authority,
            client_credential=self._client_credential,
            token_cache=cache,
        )

    def log_in(
        self,
        *,
        scopes: Sequence[str],
        redirect_uri: str,
        prompt: Optional[str] = None,
        login_hint: Optional[str] = None,
        **flow_kwargs: Any,
    ) -> Dict[str, Any]:
        cache = self._load_cache()
        app = self._build_app(cache=cache)
        kwargs: Dict[str, Any] = {"scopes": list(scopes), "redirect_uri": redirect_uri}
        if prompt:
            kwargs["prompt"] = prompt
        if login_hint:
            kwargs["login_hint"] = login_hint
        kwargs.update(flow_kwargs)
        flow = app.initiate_auth_code_flow(**kwargs)
        self._set_session_value(self._flow_session_key, flow)
        # Flow only mutates cache when the auth code is redeemed, but persist anyway.
        self._save_cache(cache)
        return {k: flow.get(k) for k in ("auth_uri", "user_code", "message") if flow.get(k)}

    def complete_log_in(self, request_args: Mapping[str, Any]) -> Dict[str, Any]:
        cached_flow: Optional[Dict[str, Any]] = self._pop_session_value(self._flow_session_key)
        if not cached_flow:
            return {"error": "session_expired", "error_description": "Missing auth flow in session."}

        cache = self._load_cache()
        app = self._build_app(cache=cache, authority=cached_flow.get("authority"))
        try:
            result = app.acquire_token_by_auth_code_flow(cached_flow, dict(request_args))
        except msal.MsalClientError as err:
            _logger.exception("Auth code redemption failed")
            return {"error": "msal_client_error", "error_description": str(err)}
        finally:
            # Ensure we do not reuse the same flow twice even if redemption fails.
            self._save_cache(cache)

        if "error" in result:
            return result

        accounts = app.get_accounts()
        account = accounts[0] if accounts else None
        id_token_claims = result.get("id_token_claims", {}) or {}
        user_record: Dict[str, Any] = {
            **id_token_claims,
            "id_token_claims": id_token_claims,
        }
        if account:
            user_record["home_account_id"] = account.get("home_account_id")
        self._set_session_value(self._user_session_key, user_record)
        self._save_cache(cache)
        return result

    def log_out(self, post_logout_redirect_uri: str) -> str:
        self._pop_session_value(self._cache_session_key)
        self._pop_session_value(self._flow_session_key)
        self._pop_session_value(self._user_session_key)
        logout_url = f"{self._authority}/oauth2/v2.0/logout"
        return f"{logout_url}?post_logout_redirect_uri={quote(post_logout_redirect_uri, safe='')}"

    def get_user(self) -> Optional[Dict[str, Any]]:
        user = self._get_session_value(self._user_session_key)
        if isinstance(user, Mapping):
            return dict(user)
        return None

    def get_token_for_user(self, scopes: Sequence[str]) -> Dict[str, Any]:
        cache = self._load_cache()
        app = self._build_app(cache=cache)
        user = self.get_user()
        account = None
        if user and user.get("home_account_id"):
            accounts = app.get_accounts(home_account_id=user["home_account_id"])
            account = accounts[0] if accounts else None
        if not account:
            accounts = app.get_accounts()
            account = accounts[0] if accounts else None
        if not account:
            return {"error": "no_account", "error_description": "User session not found in token cache."}

        result = app.acquire_token_silent(list(scopes), account=account)
        self._save_cache(cache)
        if not result:
            return {"error": "interaction_required", "error_description": "Authentication required."}
        return result
