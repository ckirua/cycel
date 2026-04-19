"""Type stubs for :mod:`cycel.net.http` (Cython / aiosonic HTTP client)."""

from typing import Any, Optional

class HTTPMethods:
    """Common HTTP verb strings (GET, POST, PUT, DELETE)."""

    GET: str
    POST: str
    PUT: str
    DELETE: str

class HTTPResponse:
    """HTTP response with status, headers, body, and a computed ``ok`` flag (2xx)."""

    status_code: int
    headers: dict
    content: bytes
    ok: bool
    def __init__(self, status_code: int, headers: dict, content: bytes) -> None: ...

class HTTPRequest:
    url: str
    method: str
    headers: dict | None
    params: dict | None
    data: dict | None
    def __init__(
        self,
        url: str,
        method: str,
        headers: dict | None = ...,
        params: dict | None = ...,
        data: dict | None = ...,
    ) -> None: ...

class HTTPClient:
    def __init__(
        self,
        connector: Any = ...,
        handle_cookies: bool = ...,
        verify_ssl: bool = ...,
        proxy: Any = ...,
    ) -> None: ...
    def connected(self) -> bool: ...
    async def __aenter__(self) -> HTTPClient: ...
    async def __aexit__(
        self,
        exc_type: Optional[type],
        exc_value: Optional[BaseException],
        traceback: Optional[object],
    ) -> None: ...
    async def _request(
        self,
        url: str,
        method: str,
        *args: Any,
        **kwargs: Any,
    ) -> Any: ...
    def connect(self) -> None: ...
    async def disconnect(self) -> None: ...
    async def wait_connection(self, timeout: Optional[float] = ...) -> None: ...
    async def request(
        self, request: HTTPRequest, *args: Any, **kwargs: Any
    ) -> HTTPResponse: ...

def verify_http_status_code(status_code: int) -> bool: ...
