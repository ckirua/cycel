"""
Binary serialization helpers.

:func:`msgpack_pack` encodes a restricted set of Python types to MessagePack
without requiring the ``msgpack`` library at runtime.
"""

from .msgpack_pack import msgpack_pack

__all__: tuple[str, ...] = ("msgpack_pack",)
