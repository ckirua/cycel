"""Type stubs for :mod:`cycel.arrow.arrow` (Cython)."""

from typing import Optional

import pyarrow as pa
import pyarrow.csv as pacsv
import pyarrow.fs as pafs

def pa_file_exists(fs: pafs.FileSystem, file_path: str) -> bool: ...
def pa_write_parquet_table(
    table: pa.Table,
    path: str,
    filesystem: Optional[pafs.FileSystem] = None,
    compression: Optional[str] = None,
) -> None: ...
def read_csv_bytes(
    content: bytes,
    read_options: Optional[pacsv.ReadOptions] = None,
    convert_options: Optional[pacsv.ConvertOptions] = None,
) -> pa.Table: ...
