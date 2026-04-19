"""
Async networking utilities.

The HTTP submodule wraps ``aiosonic`` with small request/response types suitable
for structured clients and tests.
"""

from __future__ import annotations

from .http import (HTTPClient, HTTPMethods, HTTPRequest, HTTPResponse,
                   verify_http_status_code)

__all__: tuple[str, ...] = (
    "HTTPClient",
    "HTTPMethods",
    "HTTPRequest",
    "HTTPResponse",
    "verify_http_status_code",
)
