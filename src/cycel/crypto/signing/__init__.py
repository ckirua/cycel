"""
Message signing helpers: EIP-712 typed data (Ethereum) and BIP-137 signed
messages (Bitcoin-style). The package prefers compiled extensions when present
and falls back to pure-Python ``_*`` modules for identical call signatures.
"""

try:
    from .bip137 import (
        bip137_sign_message,
        bip137_signed_message_hash,
        bip137_verify_message,
    )
except ImportError:
    from ._bip137 import (
        bip137_sign_message,
        bip137_signed_message_hash,
        bip137_verify_message,
    )

try:
    from .eip712 import eip712_hash_agent_message, eip712_hash_full_message
except ImportError:
    from ._eip712 import eip712_hash_agent_message, eip712_hash_full_message

__all__: tuple[str, ...] = (
    "bip137_sign_message",
    "bip137_signed_message_hash",
    "bip137_verify_message",
    "eip712_hash_agent_message",
    "eip712_hash_full_message",
)
