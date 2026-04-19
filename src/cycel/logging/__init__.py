"""
Lightweight logging helpers.

Exposes a typed alias for :class:`logging.Logger` and thin wrappers around
:class:`logging.getLogger` and :func:`logging.config.dictConfig` so applications
can configure logging consistently.
"""

from __future__ import annotations

import logging
import logging.config
from typing import Any

Logger: type[logging.Logger] = logging.Logger


def get_logger(name: str = "root") -> logging.Logger:
    """
    Get a logger with the given name.

    Args:
        name: The name of the logger.

    Returns:
        A logger with the given name.
    """
    return logging.getLogger(name)


def load_dict_config(logging_dict: dict[str, Any]) -> None:
    """
    Load a logging configuration from a dictionary.

    Args:
        logging_dict: The logging configuration dictionary.
    """
    logging.config.dictConfig(logging_dict)
