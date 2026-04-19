"""
Benchmark ``cycel.zmq.zmq_async`` (throughput + one-way latency).

Transport: **PUB / SUB** (with subscription handshake)
-------------------------------------------------------
The bench waits for ``subscribe()`` plus a short propagation delay before the
publisher starts its counted send loop, matching the ZMQ “slow joiner” notes.
Very large ``--measure-messages`` can still drop under load; prefer moderate
counts or split runs. (A future **PUSH/PULL** mode would be ideal for lossless
counting once validated in this stack.)

Throughput
    Publisher sends ``warmup_messages + measure_messages``; subscriber drops
    the warmup receives, then times ``measure_messages`` receives.

Latency
    Same counting model; subscriber records one-way ``perf_counter()`` stamp
    delay (same host clock).

Usage::

    python examples/zmq/bench.py throughput --measure-messages 100000
    python examples/zmq/bench.py latency --measure-samples 20000
    python examples/zmq/bench.py both --measure-messages 50000 --measure-samples 10000

Compare JSON fields ``messages_per_s``, ``latency_ms``, and ``git_revision``.

Results are also written under ``benchmarks/`` as
``zmq-bench-{mode}-{utc-timestamp}.json`` (unless ``--no-save``). Use
``--output-dir`` to override the directory.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import struct
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from types import SimpleNamespace
from typing import Any

import numpy as np

from cycel.zmq.zmq_async import ZMQPublisher, ZMQSubscriber


def _repo_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", ".."))


def _default_benchmark_dir() -> str:
    return os.path.join(_repo_root(), "benchmarks")


def _resolve_output_dir(raw: str | None) -> str:
    if raw:
        return os.path.abspath(raw)
    return _default_benchmark_dir()


def _git_revision() -> str | None:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=_repo_root(),
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def _libzmq_version() -> str | None:
    try:
        import zmq

        return zmq.zmq_version()
    except Exception:
        return None


def _payload_of_size(n: int, *, stamp: bool = False) -> bytes:
    if stamp:
        head = struct.pack("<d", time.perf_counter())
        pad = max(0, n - len(head))
        return head + b"x" * pad
    return b"p" * max(1, n)


def _parse_latency_sample(payload: bytes) -> float | None:
    if len(payload) < 8:
        return None
    (t0,) = struct.unpack("<d", payload[:8])
    return (time.perf_counter() - t0) * 1000.0


def _latency_percentiles(lat_ms: list[float]) -> dict[str, Any]:
    arr = np.asarray(lat_ms, dtype=np.float64)
    if arr.size == 0:
        return {"samples": 0, "latency_ms": {}}
    qs = np.percentile(arr, [50.0, 95.0, 99.0, 99.9]).tolist()
    return {
        "samples": int(arr.size),
        "latency_ms": {
            "min": float(arr.min()),
            "p50": float(qs[0]),
            "p95": float(qs[1]),
            "p99": float(qs[2]),
            "p99_9": float(qs[3]),
            "max": float(arr.max()),
            "mean": float(arr.mean()),
            "stdev": float(arr.std(ddof=0)),
        },
    }


@dataclass
class BenchMeta:
    mode: str
    url: str
    topic: bytes
    payload_bytes: int
    warmup_messages: int
    measure_messages: int
    measure_samples: int
    git_revision: str | None
    libzmq_version: str | None
    python: str


def _meta_for_json(meta: BenchMeta) -> dict[str, Any]:
    d = asdict(meta)
    d["topic"] = meta.topic.decode("utf-8", errors="replace")
    return d


def _emit_result(
    meta: BenchMeta,
    body: dict[str, Any],
    *,
    as_json: bool,
    save: bool,
    output_dir: str,
) -> None:
    recorded = datetime.now(timezone.utc)
    recorded_iso = recorded.isoformat().replace("+00:00", "Z")
    ts_file = recorded.strftime("%Y%m%dT%H%M%S_%fZ")
    safe_mode = meta.mode.replace(os.sep, "_").replace("/", "_")
    filename = f"zmq-bench_{safe_mode}_{ts_file}.json"
    out: dict[str, Any] = {
        "recorded_at": recorded_iso,
        "meta": _meta_for_json(meta),
        **body,
    }
    _ = as_json
    if save:
        os.makedirs(output_dir, exist_ok=True)
        path = os.path.join(output_dir, filename)
        try:
            rel = os.path.relpath(path, _repo_root())
        except ValueError:
            rel = path
        out["result_path"] = rel.replace(os.sep, "/")
    text = json.dumps(out, indent=2)
    print(text)
    if save:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"Wrote {path}", file=sys.stderr)


async def _run_throughput(
    *,
    url: str,
    topic: bytes,
    payload: bytes,
    warmup_n: int,
    measure_n: int,
) -> dict[str, Any]:
    params_pub = SimpleNamespace(url=url)
    params_sub = SimpleNamespace(url=url)
    sub_ready = asyncio.Event()

    async def publisher() -> None:
        async with ZMQPublisher(params_pub) as pub:
            await sub_ready.wait()
            for _ in range(warmup_n + measure_n):
                await pub.send_multipart_async(topic, payload)

    async def subscriber() -> tuple[int, int, float]:
        await asyncio.sleep(0.05)
        async with ZMQSubscriber(params_sub) as sub:
            sub.subscribe(topic)
            await asyncio.sleep(0.15)
            sub_ready.set()
            for _ in range(warmup_n):
                await sub.recv_multipart_async()
            total_bytes = 0
            t0 = time.perf_counter()
            for _ in range(measure_n):
                frames = await sub.recv_multipart_async()
                for f in frames:
                    total_bytes += len(f)
            dt = time.perf_counter() - t0
        return measure_n, total_bytes, dt

    _, (n_msg, total_bytes, dt) = await asyncio.gather(publisher(), subscriber())
    mps = n_msg / dt if dt > 0 else 0.0
    mbps = (total_bytes / dt) / (1024 * 1024) if dt > 0 else 0.0
    return {
        "measure_seconds": round(dt, 6),
        "messages": n_msg,
        "message_bytes_on_wire_estimate": total_bytes,
        "messages_per_s": round(mps, 3),
        "megabytes_per_s": round(mbps, 6),
    }


async def _run_latency(
    *,
    url: str,
    topic: bytes,
    payload_size: int,
    warmup_n: int,
    sample_n: int,
) -> dict[str, Any]:
    params_pub = SimpleNamespace(url=url)
    params_sub = SimpleNamespace(url=url)
    sub_ready = asyncio.Event()

    async def publisher() -> None:
        async with ZMQPublisher(params_pub) as pub:
            await sub_ready.wait()
            for _ in range(warmup_n + sample_n):
                body = _payload_of_size(payload_size, stamp=True)
                await pub.send_multipart_async(topic, body)

    async def subscriber() -> list[float]:
        await asyncio.sleep(0.05)
        async with ZMQSubscriber(params_sub) as sub:
            sub.subscribe(topic)
            await asyncio.sleep(0.15)
            sub_ready.set()
            for _ in range(warmup_n):
                await sub.recv_multipart_async()
            lat_ms: list[float] = []
            for _ in range(sample_n):
                frames = await sub.recv_multipart_async()
                body = frames[-1]
                sample = _parse_latency_sample(body)
                if sample is not None:
                    lat_ms.append(sample)
            return lat_ms

    _, lat_ms = await asyncio.gather(publisher(), subscriber())
    return _latency_percentiles(lat_ms)


def _build_meta(mode: str, args: argparse.Namespace) -> BenchMeta:
    return BenchMeta(
        mode=mode,
        url=args.url,
        topic=args.topic.encode() if isinstance(args.topic, str) else args.topic,
        payload_bytes=args.payload_bytes,
        warmup_messages=args.warmup_messages,
        measure_messages=args.measure_messages,
        measure_samples=args.measure_samples,
        git_revision=_git_revision(),
        libzmq_version=_libzmq_version(),
        python=sys.version.split()[0],
    )


async def _cmd_throughput(args: argparse.Namespace) -> None:
    meta = _build_meta("throughput", args)
    topic = meta.topic
    payload = _payload_of_size(args.payload_bytes, stamp=False)
    merged: dict[str, Any] = {}
    for run in range(args.runs):
        merged[f"run_{run}"] = await _run_throughput(
            url=args.url,
            topic=topic,
            payload=payload,
            warmup_n=args.warmup_messages,
            measure_n=args.measure_messages,
        )
    mps_list = [merged[f"run_{i}"]["messages_per_s"] for i in range(args.runs)]
    merged["messages_per_s_median_over_runs"] = float(np.median(mps_list))
    _emit_result(
        meta,
        merged,
        as_json=args.json,
        save=not args.no_save,
        output_dir=_resolve_output_dir(args.output_dir),
    )


async def _cmd_latency(args: argparse.Namespace) -> None:
    meta = _build_meta("latency", args)
    topic = meta.topic
    merged: dict[str, Any] = {}
    for run in range(args.runs):
        merged[f"run_{run}"] = await _run_latency(
            url=args.url,
            topic=topic,
            payload_size=args.payload_bytes,
            warmup_n=args.warmup_messages,
            sample_n=args.measure_samples,
        )
    _emit_result(
        meta,
        merged,
        as_json=args.json,
        save=not args.no_save,
        output_dir=_resolve_output_dir(args.output_dir),
    )


async def _cmd_both(args: argparse.Namespace) -> None:
    meta = _build_meta("both", args)
    topic = meta.topic
    payload = _payload_of_size(args.payload_bytes, stamp=False)
    out: dict[str, Any] = {}
    for run in range(args.runs):
        tp = await _run_throughput(
            url=args.url,
            topic=topic,
            payload=payload,
            warmup_n=args.warmup_messages,
            measure_n=args.measure_messages,
        )
        lat = await _run_latency(
            url=args.url,
            topic=topic,
            payload_size=args.payload_bytes,
            warmup_n=args.warmup_messages,
            sample_n=args.measure_samples,
        )
        out[f"run_{run}"] = {"throughput": tp, "latency": lat}
    mps = [out[f"run_{i}"]["throughput"]["messages_per_s"] for i in range(args.runs)]
    out["messages_per_s_median_over_runs"] = float(np.median(mps))
    _emit_result(
        meta,
        out,
        as_json=args.json,
        save=not args.no_save,
        output_dir=_resolve_output_dir(args.output_dir),
    )


def _add_common(p: argparse.ArgumentParser) -> None:
    p.add_argument(
        "--url",
        default="tcp://127.0.0.1:5599",
        help="Endpoint (tcp recommended). Change if another process holds the port.",
    )
    p.add_argument(
        "--topic",
        default="bench",
        help="First multipart frame (label); second frame is the payload.",
    )
    p.add_argument(
        "--payload-bytes",
        type=int,
        default=64,
        help="Payload size (latency mode prefixes 8-byte timestamp).",
    )
    p.add_argument(
        "--warmup-messages",
        type=int,
        default=500,
        help="Messages to pre-send before timed / sampled section.",
    )
    p.add_argument("--runs", type=int, default=1, help="Repeat runs (throughput: median msg/s).")
    p.add_argument("--json", action="store_true", help="Reserved for non-JSON output later.")
    p.add_argument(
        "--output-dir",
        default=None,
        metavar="DIR",
        help="Where to write JSON (default: <repo>/benchmarks).",
    )
    p.add_argument(
        "--no-save",
        action="store_true",
        help="Only print JSON to stdout; do not write a file.",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_tp = sub.add_parser("throughput", help="Messages/s over a fixed receive batch.")
    _add_common(p_tp)
    p_tp.add_argument(
        "--measure-messages",
        type=int,
        default=50_000,
        help="Counted receives in the timed window (after warmup).",
    )
    p_tp.set_defaults(measure_samples=0, func=lambda a: asyncio.run(_cmd_throughput(a)))

    p_lat = sub.add_parser("latency", help="One-way stamped latency percentiles.")
    _add_common(p_lat)
    p_lat.add_argument(
        "--measure-samples",
        type=int,
        default=20_000,
        help="Latency samples after warmup.",
    )
    p_lat.set_defaults(measure_messages=0, func=lambda a: asyncio.run(_cmd_latency(a)))

    p_both = sub.add_parser("both", help="Throughput then latency.")
    _add_common(p_both)
    p_both.add_argument("--measure-messages", type=int, default=50_000)
    p_both.add_argument("--measure-samples", type=int, default=10_000)
    p_both.set_defaults(func=lambda a: asyncio.run(_cmd_both(a)))

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
