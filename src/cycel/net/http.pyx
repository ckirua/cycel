from typing import Any, Optional

cimport cython

import asyncio

import aiosonic

DEF HTTP_OK_STATUS_CODE = 200
DEF HTTP_ERROR_STATUS_CODE = 300

cpdef inline bint verify_http_status_code(int status_code) noexcept nogil:
    # True iff 200 <= status_code < 300 (2xx). Documented in ``cycel.net`` API.
    return HTTP_OK_STATUS_CODE <= status_code < HTTP_ERROR_STATUS_CODE


@cython.final
cdef class HTTPMethods:
    """Common HTTP method name constants for clients and tests."""
    GET: str = "GET"
    POST: str = "POST"
    PUT: str = "PUT"
    DELETE: str = "DELETE"


cdef class HTTPResponse:
    """
    Normalized HTTP response: status, header mapping, and raw body bytes.

    ``ok`` mirrors :func:`verify_http_status_code` on ``status_code``.
    """

    def __cinit__(self, int status_code, dict headers, bytes content):
        self.status_code = status_code
        self.headers = headers
        self.content = content
        self.ok = verify_http_status_code(status_code)


cdef class HTTPRequest:
    """Immutable-style request descriptor; body/query/header maps may be empty or omitted."""

    def __cinit__(
        self,
        str url,
        str method,
        dict headers=None,
        dict params=None,
        dict data=None,
    ):
        self.url = url
        self.method = method
        self.headers = headers
        self.params = params
        self.data = data


cdef class HTTPClient:
    """Async HTTP client backed by aiosonic.

    Configure the client in ``__init__``, then either:

    - ``async with HTTPClient(...) as client: ...``, or
    - call ``connect()`` and later ``await disconnect()``.
    """

    def __init__(
        self,
        connector: Optional[aiosonic.TCPConnector] = None,
        handle_cookies: bool = False,
        verify_ssl: bool = True,
        proxy: Optional[aiosonic.Proxy] = None,
    ):
        self._session = None
        self._connection_event = asyncio.Event()
        self._connector = connector
        self._handle_cookies = handle_cookies
        self._verify_ssl = verify_ssl
        self._proxy = proxy

    cpdef bint connected(self):
        return self._connection_event.is_set()

    async def __aenter__(self):
        if not self.connected():
            self.connect()
        return self

    async def __aexit__(
        self,
        exc_type: Optional[type],
        exc_value: Optional[BaseException],
        traceback: Optional[object],
    ) -> None:
        await self.disconnect()

    async def _request(
        self,
        url: str,
        method: str,
        *args,
        **kwargs: Any,
    ) -> aiosonic.HttpResponse:
        return await self._session.request(url, method, *args, **kwargs)

    cpdef void connect(self):
        if self._session is not None:
            raise RuntimeError(
                "HTTPClient is already connected; await disconnect() before connect()"
            )
        self._session = aiosonic.HTTPClient(
            connector=self._connector,
            handle_cookies=self._handle_cookies,
            verify_ssl=self._verify_ssl,
            proxy=self._proxy,
        )
        self._connection_event.set()

    async def disconnect(self):
        session = self._session
        if session is None:
            return
        connector = getattr(session, "connector", None)
        if connector is not None:
            await connector.cleanup()
        self._session = None
        self._connection_event.clear()

    async def wait_connection(self, timeout: Optional[float] = None) -> None:
        await asyncio.wait_for(self._connection_event.wait(), timeout=timeout)

    async def request(self, request: HTTPRequest, *args: Any, **kwargs: Any) -> HTTPResponse:
        if self._session is None:
            raise RuntimeError(
                "HTTPClient is not connected; use 'async with HTTPClient(...)' or call connect()"
            )
        resp = await self._request(
            request.url,
            request.method,
            *args,
            headers=request.headers,
            params=request.params,
            data=request.data,
            **kwargs,
        )
        content = await resp.content()
        connection = getattr(resp, "_connection", None)
        if connection is not None and getattr(connection, "blocked", False):
            connection.release()
        return HTTPResponse(resp.status_code, dict(resp.headers), content)
