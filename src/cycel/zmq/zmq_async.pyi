# pylint: disable=unused-argument,redefined-builtin
from __future__ import annotations

import asyncio
from typing import Any, Optional, Protocol


class _SocketParameters(Protocol):
    url: str | bytes


class ZMQSocket:
    """Async-capable ZMQ socket; see :mod:`cycel.zmq` for concrete socket types."""

    _fd: int
    _loop: asyncio.AbstractEventLoop | None
    _recv_futures: list[Any]
    _send_futures: list[Any]

    def _on_readable(self) -> None: ...
    def _on_writable(self) -> None: ...
    async def send_multipart_async(self, topic: bytes, data: bytes) -> None: ...
    async def send_bytes_async(self, data: bytes) -> None: ...
    async def recv_multipart_async(self) -> list[bytes]: ...
    async def recv_bytes_async(self) -> bytes: ...
    def send_multipart(self, topic: bytes, data: bytes) -> None: ...
    def send_bytes(self, data: bytes) -> None: ...
    def recv_multipart(self) -> list[bytes]: ...
    def recv_bytes(self) -> bytes: ...
    async def __aenter__(self) -> ZMQSocket: ...
    async def __aexit__(self, *args: Any) -> None: ...


class ZMQPublisher(ZMQSocket):
    """PUB socket: binds on async context manager entry."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQPublisher: ...


class ZMQSubscriber(ZMQSocket):
    """SUB socket: connects on entry; filter topics via :meth:`subscribe`."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQSubscriber: ...
    def subscribe(self, topic: bytes = b"") -> ZMQSubscriber: ...


class ZMQRouter(ZMQSocket):
    """ROUTER socket: binds; speaks to DEALER/REQ peers."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQRouter: ...


class ZMQDealer(ZMQSocket):
    """DEALER socket: connects; pairs with ROUTER."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQDealer: ...


class ZMQPush(ZMQSocket):
    """PUSH socket: connects toward a PULL peer."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQPush: ...


class ZMQPull(ZMQSocket):
    """PULL socket: binds; receives pipeline messages."""

    def __init__(
        self,
        socket_parameters: _SocketParameters,
        id: Optional[bytes] = None,
    ) -> None: ...

    async def __aenter__(self) -> ZMQPull: ...
