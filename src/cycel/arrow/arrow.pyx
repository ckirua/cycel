"""
PyArrow-backed helpers for CSV reads, Parquet writes, and file existence checks.
"""

import io

import pyarrow.csv as pacsv
import pyarrow.parquet as pq

from libcpp.memory cimport shared_ptr
from pyarrow._csv cimport ConvertOptions, ReadOptions
from pyarrow._fs cimport FileSystem
from pyarrow.includes.common cimport GetResultValue
from pyarrow.includes.libarrow_fs cimport (CFileInfo, CFileSystem,
                                           CFileType_File)
from pyarrow.lib cimport Table


cpdef bint pa_file_exists(object fs, str file_path) except *:
    """
    Return whether ``file_path`` exists as a regular file on ``fs``.

    Args:
        fs: A :class:`pyarrow.fs.FileSystem` instance.
        file_path: Path understood by that filesystem.

    Returns:
        ``True`` if the path exists and is a file; ``False`` for missing keys on
        object stores; re-raises other errors as :exc:`RuntimeError`.

    Raises:
        TypeError: If ``fs`` is not a ``FileSystem``.
    """
    cdef shared_ptr[CFileSystem] c_fs
    cdef CFileInfo info

    if not isinstance(fs, FileSystem):
        raise TypeError("fs must be a pyarrow.fs.FileSystem instance")

    c_fs = (<FileSystem>fs).unwrap()

    try:
        info = GetResultValue(c_fs.get().GetFileInfo(file_path.encode("utf8")))
        return info.type() == CFileType_File
    except Exception as e:
        if "NO_SUCH_KEY" in str(e) or "NoSuchKey" in str(e):
            return False
        raise RuntimeError(f"Error checking file existence: {e}") from e


cpdef Table read_csv_bytes(
    bytes content,
    ReadOptions read_options = None,
    ConvertOptions convert_options = None,
):
    """
    Parse CSV from in-memory bytes into an Arrow :class:`~pyarrow.Table`.

    Args:
        content: Raw CSV payload.
        read_options: Optional PyArrow read options (defaults used if omitted).
        convert_options: Optional type/conversion options.

    Returns:
        Parsed table.
    """
    bytes_io = io.BytesIO(content)
    
    if read_options is None:
        read_options = ReadOptions()
    if convert_options is None:
        convert_options = ConvertOptions()

    return pacsv.read_csv(
        bytes_io,
        read_options=read_options,
        convert_options=convert_options
    )

cpdef void pa_write_parquet_table(
    Table table,
    str path,
    object filesystem = None,
    str compression = None,
):
    """
    Write ``table`` to Parquet at ``path`` using ``pyarrow.parquet.write_table``.

    Args:
        table: Arrow table to persist.
        path: Destination path (filesystem-specific).
        filesystem: Optional :class:`pyarrow.fs.FileSystem` (local if omitted).
        compression: Optional codec name passed through to PyArrow.
    """
    pq.write_table(
            table,
            path,
            filesystem=filesystem,
            compression=compression
        )