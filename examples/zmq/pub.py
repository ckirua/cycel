"""
Async PUB/SUB example using ``cycel.zmq.zmq_async``.

Each socket type owns its own libzmq context, so endpoints must be
transport types that work across contexts (e.g. ``tcp://``, not ``inproc://``).

Run::

    python examples/zmq.py
"""

from __future__ import annotations

import asyncio
from types import SimpleNamespace

from cycel.zmq.zmq_async import ZMQPublisher


async def run_publisher(url: str) -> None:
    i = 0
    params = SimpleNamespace(url=url)
    async with ZMQPublisher(params) as pub:
        while True:
            i+=1
            await pub.send_multipart_async(b"events", f"hello {i}".encode())
            await asyncio.sleep(0.05)

if __name__ == "__main__":
    asyncio.run(run_publisher("tcp://127.0.0.1:5599"))