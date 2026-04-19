"""
Cryptographic hash functions.

Currently exposes Keccak-256 (Ethereum ``keccak256``), implemented in Cython
when built, with a compatible pure-Python module as fallback.
"""

from .keccak import keccak256

__all__: tuple[str, ...] = ("keccak256",)
