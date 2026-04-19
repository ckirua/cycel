"""
Public crypto API: Keccak-256, secp256k1 / Ed25519 curves, EIP-712, BIP-137, msgpack.

Typical entry points are :func:`keccak256`, :func:`sign_recoverable`,
:func:`privkey_to_address`, and :func:`eip712_hash_full_message`. Curve and hash
implementations are accelerated with Cython where available; pure-Python
fallbacks exist for the same symbols when extensions are not built.

.. note::
    :data:`__version__` is the ``cycel`` package version (same as
    :mod:`cycel.__about__`).
"""

from ..__about__ import __version__

from .curves import (
    ed25519_public_key,
    ed25519_sign,
    ed25519_verify,
    privkey_to_address,
    privkey_to_pubkey,
    recover_pubkey,
    sign_recoverable,
)
from .hashes import keccak256
from .serde import msgpack_pack
from .signing import (
    bip137_sign_message,
    bip137_signed_message_hash,
    bip137_verify_message,
    eip712_hash_agent_message,
    eip712_hash_full_message,
)

__all__: tuple[str, ...] = (
    # About
    "__version__",
    # Hashes
    "keccak256",
    # Serde
    "msgpack_pack",
    # Curves: secp256k1 (Ethereum / Bitcoin)
    "privkey_to_address",
    "privkey_to_pubkey",
    "recover_pubkey",
    "sign_recoverable",
    # Curves: Ed25519 (Solana etc.)
    "ed25519_public_key",
    "ed25519_sign",
    "ed25519_verify",
    # Signing: EIP-712 (Ethereum typed data)
    "eip712_hash_agent_message",
    "eip712_hash_full_message",
    # Signing: BIP-137 (Bitcoin signed messages)
    "bip137_sign_message",
    "bip137_signed_message_hash",
    "bip137_verify_message",
)
