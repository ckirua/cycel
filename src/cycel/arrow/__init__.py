"""
Apache Arrow helpers (PyArrow).

Thin wrappers for common I/O checks and CSV/Parquet round-trips without pulling
extra high-level dependencies into call sites.
"""

from __future__ import annotations

from .arrow import pa_file_exists, pa_write_parquet_table, read_csv_bytes

__all__: tuple[str, ...] = (
    "pa_file_exists",
    "pa_write_parquet_table",
    "read_csv_bytes",
)
