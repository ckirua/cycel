# zmq_async.pyx
# cython: language_level=3

from libc.string cimport memcpy
from libc.errno cimport errno, EAGAIN

from cycel.zmq cimport libzmq

import asyncio
import secrets


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

cdef int _get_fd(void* socket) except -1:
    """Extract ZMQ_FD from a raw libzmq socket — the OS fd asyncio can watch."""
    cdef int fd
    cdef size_t fd_size = sizeof(fd)
    cdef int rc = libzmq.zmq_getsockopt(socket, libzmq.ZMQ_FD, &fd, &fd_size)
    if rc != 0:
        raise RuntimeError(f"zmq_getsockopt(ZMQ_FD) failed: errno={errno}")
    return fd

cdef int _get_events(void* socket) except -1:
    """Read ZMQ_EVENTS bitmask — tells us if POLLIN/POLLOUT are set."""
    cdef int events
    cdef size_t ev_size = sizeof(events)
    cdef int rc = libzmq.zmq_getsockopt(socket, libzmq.ZMQ_EVENTS, &events, &ev_size)
    if rc != 0:
        raise RuntimeError(f"zmq_getsockopt(ZMQ_EVENTS) failed: errno={errno}")
    return events


# ──────────────────────────────────────────────────────────────────────────────
# Base class
# ──────────────────────────────────────────────────────────────────────────────

cdef class ZMQSocket:
    """
    Base async ZMQ socket bound to an OS file descriptor for ``asyncio``.

    Subclasses set ``ZMQ_*`` socket types and bind/connect in ``__aenter__``.
    Prefer the ``*_async`` send/receive methods inside coroutines; synchronous
    methods block the thread using blocking ``zmq_msg_recv``.
    """
    def __cinit__(self, *args, **kwargs):
        self._ctx = NULL
        self._socket = NULL
        self._fd = -1
        self._loop = None
        self._recv_futures = []
        self._send_futures = []

    cdef int _initialize(self) except -1:
        self._ctx = libzmq.zmq_ctx_new()
        if self._ctx == NULL:
            raise RuntimeError("Failed to create zmq context")

        self._socket = libzmq.zmq_socket(self._ctx, self._socket_type)
        if self._socket == NULL:
            raise RuntimeError("Failed to create zmq socket")

        cdef int zero = 0
        libzmq.zmq_setsockopt(self._socket, libzmq.ZMQ_LINGER, &zero, sizeof(zero))

        cdef bytes identity = self._id
        cdef const char* id_ptr = identity
        libzmq.zmq_setsockopt(self._socket, libzmq.ZMQ_IDENTITY, id_ptr, len(identity))

        # Grab the OS fd so asyncio can watch it
        self._fd = _get_fd(self._socket)
        return 0

    cdef int _close(self) except -1:
        if self._loop is not None and self._fd != -1:
            try:
                self._loop.remove_reader(self._fd)
                self._loop.remove_writer(self._fd)
            except Exception:
                pass
        # Cancel any pending futures (entries are (kind, fut) or (kind, ... , fut))
        for item in self._recv_futures:
            fut = item[1]
            if not fut.done():
                fut.cancel()
        for item in self._send_futures:
            fut = item[-1]
            if not fut.done():
                fut.cancel()
        self._recv_futures.clear()
        self._send_futures.clear()
        if self._socket != NULL:
            libzmq.zmq_close(self._socket)
            self._socket = NULL
        if self._ctx != NULL:
            libzmq.zmq_ctx_destroy(self._ctx)
            self._ctx = NULL
        self._fd = -1
        return 0

    cdef bytes _get_url(self):
        url = self._socket_parameters.url
        if isinstance(url, str):
            return url.encode()
        return url

    # ── Sync send/recv (hot path, nogil, unchanged from original) ─────────────

    cdef int _send_multipart_nowait(self, bytes topic, bytes data) except -1:
        """Non-blocking multipart send. Returns 0 on success, raises on EAGAIN."""
        cdef const char* topic_ptr = topic
        cdef const char* data_ptr = data
        cdef size_t topic_len = len(topic)
        cdef size_t data_len = len(data)
        cdef libzmq.zmq_msg_t msg
        cdef int rc

        with nogil:
            libzmq.zmq_msg_init_size(&msg, topic_len)
            memcpy(libzmq.zmq_msg_data(&msg), topic_ptr, topic_len)
            rc = libzmq.zmq_msg_send(&msg, self._socket, libzmq.ZMQ_SNDMORE | libzmq.ZMQ_DONTWAIT)
            libzmq.zmq_msg_close(&msg)

        if rc < 0:
            if errno == EAGAIN:
                raise BlockingIOError("zmq send would block")
            raise RuntimeError(f"zmq_msg_send failed: errno={errno}")

        with nogil:
            libzmq.zmq_msg_init_size(&msg, data_len)
            memcpy(libzmq.zmq_msg_data(&msg), data_ptr, data_len)
            rc = libzmq.zmq_msg_send(&msg, self._socket, libzmq.ZMQ_DONTWAIT)
            libzmq.zmq_msg_close(&msg)

        if rc < 0:
            raise RuntimeError(f"zmq_msg_send (data frame) failed: errno={errno}")
        return 0

    cdef int _send_bytes_nowait(self, bytes data) except -1:
        """Single-part non-blocking send (one ZMQ message, one frame)."""
        cdef const char* data_ptr = data
        cdef size_t data_len = len(data)
        cdef libzmq.zmq_msg_t msg
        cdef int rc

        with nogil:
            libzmq.zmq_msg_init_size(&msg, data_len)
            memcpy(libzmq.zmq_msg_data(&msg), data_ptr, data_len)
            rc = libzmq.zmq_msg_send(&msg, self._socket, libzmq.ZMQ_DONTWAIT)
            libzmq.zmq_msg_close(&msg)

        if rc < 0:
            if errno == EAGAIN:
                raise BlockingIOError("zmq send would block")
            raise RuntimeError(f"zmq_msg_send (single frame) failed: errno={errno}")
        return 0

    cdef list _recv_multipart_nowait(self):
        """
        Non-blocking multipart recv.
        Returns list of frames, or None if EAGAIN (nothing ready).
        """
        cdef libzmq.zmq_msg_t msg
        cdef list frames = []
        cdef int more = 0
        cdef size_t more_size = sizeof(more)
        cdef size_t msg_size
        cdef bytes frame
        cdef int rc

        while True:
            libzmq.zmq_msg_init(&msg)
            rc = libzmq.zmq_msg_recv(&msg, self._socket, libzmq.ZMQ_DONTWAIT)
            if rc < 0:
                libzmq.zmq_msg_close(&msg)
                if errno == EAGAIN:
                    return None   # caller should wait for ZMQ_FD to fire again
                raise RuntimeError(f"zmq_msg_recv failed: errno={errno}")
            msg_size = libzmq.zmq_msg_size(&msg)
            frame = (<char*>libzmq.zmq_msg_data(&msg))[:msg_size]
            frames.append(frame)
            libzmq.zmq_msg_close(&msg)
            libzmq.zmq_getsockopt(self._socket, libzmq.ZMQ_RCVMORE, &more, &more_size)
            if not more:
                break

        return frames

    # ── Asyncio integration ───────────────────────────────────────────────────

    def _on_readable(self):
        """
        Called by asyncio's selector when ZMQ_FD fires (edge-triggered!).

        ZMQ_FD is edge-triggered: it fires once when the socket transitions
        from "no events" → "has events". We must drain ZMQ_EVENTS in a loop
        until it returns 0, otherwise we can miss messages.
        """
        # Drain all available messages while POLLIN is set
        while True:
            events = _get_events(self._socket)
            if not (events & libzmq.ZMQ_POLLIN):
                break
            if not self._recv_futures:
                # Nobody waiting — stop watching until someone calls recv()
                # (we'll re-arm in recv_multipart_async)
                self._loop.remove_reader(self._fd)
                return
            frames = self._recv_multipart_nowait()
            if frames is None:
                break
            kind, fut = self._recv_futures.pop(0)
            if fut.done():
                continue
            if kind == "m":
                fut.set_result(frames)
            else:
                if len(frames) != 1:
                    fut.set_exception(
                        ValueError(
                            "multi-frame ZMQ message received; use recv_multipart_async"
                        )
                    )
                else:
                    fut.set_result(frames[0])

    def _on_writable(self):
        """Called when ZMQ_FD fires with POLLOUT — unblock a pending send."""
        while self._send_futures:
            events = _get_events(self._socket)
            if not (events & libzmq.ZMQ_POLLOUT):
                break
            item = self._send_futures.pop(0)
            fut = item[-1]
            if fut.done():
                continue
            try:
                if item[0] == "m":
                    self._send_multipart_nowait(item[1], item[2])
                else:
                    self._send_bytes_nowait(item[1])
                fut.set_result(None)
            except Exception as e:
                fut.set_exception(e)
        if not self._send_futures:
            try:
                self._loop.remove_writer(self._fd)
            except Exception:
                pass

    async def send_multipart_async(self, bytes topic, bytes data):
        """
        Async send. Fast path: try immediately with DONTWAIT.
        Slow path (HWM hit): yield to event loop and retry when writable.
        """
        try:
            self._send_multipart_nowait(topic, data)
            return
        except BlockingIOError:
            pass
        # Slow path — register write interest and wait
        fut = self._loop.create_future()
        self._send_futures.append(("m", topic, data, fut))
        self._loop.add_writer(self._fd, self._on_writable)
        await fut

    async def send_bytes_async(self, bytes data):
        """Async single-frame send (payload only; use with orjson/SBE-encoded bytes)."""
        try:
            self._send_bytes_nowait(data)
            return
        except BlockingIOError:
            pass
        fut = self._loop.create_future()
        self._send_futures.append(("b", data, fut))
        self._loop.add_writer(self._fd, self._on_writable)
        await fut

    async def recv_multipart_async(self):
        """
        Async recv. Fast path: check ZMQ_EVENTS before yielding.
        If data is already queued in libzmq, we never touch asyncio.
        """
        # Fast path: drain immediately if data is available
        # (ZMQ_FD may not have fired if we missed the edge)
        events = _get_events(self._socket)
        if events & libzmq.ZMQ_POLLIN:
            frames = self._recv_multipart_nowait()
            if frames is not None:
                return frames

        # Slow path — arm reader and wait
        fut = self._loop.create_future()
        self._recv_futures.append(("m", fut))
        # add_reader is idempotent — safe to call even if already watching
        self._loop.add_reader(self._fd, self._on_readable)
        return await fut

    async def recv_bytes_async(self):
        """Async single-frame recv (one ZMQ message == one frame). Multi-frame raises."""
        events = _get_events(self._socket)
        if events & libzmq.ZMQ_POLLIN:
            frames = self._recv_multipart_nowait()
            if frames is not None:
                if len(frames) != 1:
                    raise ValueError(
                        "multi-frame ZMQ message received; use recv_multipart_async"
                    )
                return frames[0]

        fut = self._loop.create_future()
        self._recv_futures.append(("b", fut))
        self._loop.add_reader(self._fd, self._on_readable)
        return await fut

    # ── Sync surface (preserved for backwards compat) ─────────────────────────

    def send_multipart(self, bytes topic, bytes data):
        self._send_multipart_nowait(topic, data)

    def send_bytes(self, bytes data):
        """Blocking single-frame send (DONTWAIT semantics may still raise)."""
        self._send_bytes_nowait(data)

    def recv_multipart(self):
        # Blocking sync version — kept for non-async callers
        cdef libzmq.zmq_msg_t msg
        cdef list frames = []
        cdef int more = 0
        cdef size_t more_size = sizeof(more)
        cdef size_t msg_size
        cdef bytes frame

        while True:
            libzmq.zmq_msg_init(&msg)
            libzmq.zmq_msg_recv(&msg, self._socket, 0)
            msg_size = libzmq.zmq_msg_size(&msg)
            frame = (<char*>libzmq.zmq_msg_data(&msg))[:msg_size]
            frames.append(frame)
            libzmq.zmq_msg_close(&msg)
            libzmq.zmq_getsockopt(self._socket, libzmq.ZMQ_RCVMORE, &more, &more_size)
            if not more:
                break
        return frames

    def recv_bytes(self):
        """Blocking recv of a single-frame ZMQ message (raises if multipart)."""
        frames = self.recv_multipart()
        if len(frames) != 1:
            raise ValueError(
                "multi-frame ZMQ message received; use recv_multipart"
            )
        return frames[0]

    async def __aenter__(self):
        raise NotImplementedError

    async def __aexit__(self, *args, **kwargs):
        self._close()


# ──────────────────────────────────────────────────────────────────────────────
# Concrete socket types
# ──────────────────────────────────────────────────────────────────────────────

cdef class ZMQPublisher(ZMQSocket):
    """PUB socket: binds on enter; publishes multipart ``(topic, data)`` frames."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_PUB
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_bind(self._socket, url)
        return self


cdef class ZMQSubscriber(ZMQSocket):
    """SUB socket: connects on enter; call :meth:`subscribe` before receiving."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_SUB
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_connect(self._socket, url)
        return self

    def subscribe(self, bytes topic=b""):
        cdef const char* topic_ptr = topic
        libzmq.zmq_setsockopt(self._socket, libzmq.ZMQ_SUBSCRIBE, topic_ptr, len(topic))
        return self


cdef class ZMQRouter(ZMQSocket):
    """ROUTER socket: binds; peers are DEALER or REQ identities in frames."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_ROUTER
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_bind(self._socket, url)
        return self


cdef class ZMQDealer(ZMQSocket):
    """DEALER socket: connects; typically pairs with ROUTER or ROUTER-like peers."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_DEALER
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_connect(self._socket, url)
        return self


cdef class ZMQPush(ZMQSocket):
    """PUSH socket: connects to a PULL sink (pipeline pattern)."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_PUSH
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_connect(self._socket, url)
        return self


cdef class ZMQPull(ZMQSocket):
    """PULL socket: binds; receives messages pushed from PUSH peers."""

    def __cinit__(self, socket_parameters, id=None):
        self._socket_type = libzmq.ZMQ_PULL
        self._socket_parameters = socket_parameters
        self._id = id or secrets.token_hex(8).encode("ascii")

    async def __aenter__(self):
        self._initialize()
        self._loop = asyncio.get_event_loop()
        cdef bytes url = self._get_url()
        libzmq.zmq_bind(self._socket, url)
        return self