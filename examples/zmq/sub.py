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

from cycel.zmq.zmq_async import ZMQSubscriber


async def run_subscriber(url: str, n_messages: int = 5) -> None:
    await asyncio.sleep(0.05)
    params = SimpleNamespace(url=url)
    async with ZMQSubscriber(params) as sub:
        sub.subscribe(b"events")
        while True:
            frames = await sub.recv_multipart_async()
            topic, payload = frames[0], frames[1]
            print(f"subscriber: topic={topic!r} payload={payload!r}")


async def main() -> None:
    url = "tcp://127.0.0.1:5599"
    n = 5
    await asyncio.gather(
        run_subscriber(url, n),
    )


if __name__ == "__main__":
    asyncio.run(main())
