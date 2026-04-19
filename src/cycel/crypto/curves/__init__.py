"""
Elliptic-curve primitives (Cython).

* **secp256k1** — uncompressed public keys, ECDSA with public-key recovery
  (Ethereum / Bitcoin style).
* **Ed25519** — RFC 8032 sign/verify (common on Solana and other Ed25519 chains).
"""

from .ed25519 import ed25519_public_key, ed25519_sign, ed25519_verify
from .secp256k1 import (
    privkey_to_address,
    privkey_to_pubkey,
    recover_pubkey,
    sign_recoverable,
)

__all__: tuple[str, ...] = (
    "ed25519_public_key",
    "ed25519_sign",
    "ed25519_verify",
    "privkey_to_address",
    "privkey_to_pubkey",
    "recover_pubkey",
    "sign_recoverable",
)
