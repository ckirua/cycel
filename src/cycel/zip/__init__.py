"""
In-memory ZIP parsing via ``libzip`` (pybind11 extension).

:func:`extract_zip` returns a list of :class:`ZipFile` records; use
:meth:`ZipFile.get_data_as_bytes` when you need a Python ``bytes`` object from
the internal ``std::vector`` backing store.
"""

from .zip import ZipFile, extract_zip

__all__: tuple[str, ...] = ("ZipFile", "extract_zip")
