from pyarrow._csv cimport ConvertOptions, ReadOptions
from pyarrow.lib cimport Table


cpdef bint pa_file_exists(object fs, str file_path) except *

cpdef Table read_csv_bytes(
    bytes content,
    ReadOptions read_options = *,
    ConvertOptions convert_options = *,
)

cpdef void pa_write_parquet_table(
    Table table,
    str path,
    object filesystem = *,
    str compression = *,
)