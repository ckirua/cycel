from posix.fcntl cimport O_RDONLY
from posix.fcntl cimport open as c_open
from posix.mman cimport MAP_PRIVATE, PROT_READ, mmap, munmap
from posix.types cimport off_t
from posix.unistd cimport SEEK_END, SEEK_SET
from posix.unistd cimport close as c_close
from posix.unistd cimport lseek

from cpython.bytes cimport PyBytes_FromStringAndSize
from cpython.list cimport (PyList_Append, PyList_GET_ITEM, PyList_GET_SIZE,
                           PyList_New, PyList_SetSlice)
from cpython.object cimport PyObject_Str
from cpython.unicode cimport PyUnicode_DecodeUTF8
from libc.stdio cimport FILE, fclose, feof, ferror, fgets, fopen
from libc.stdlib cimport free, malloc
from libc.string cimport memcpy, strlen

import os
from typing import Iterator, List, Optional, Union


cdef extern from "Python.h":
    ctypedef long Py_ssize_t
    object PyUnicode_FromString(const char*)
    int PyOS_snprintf(char *str, size_t size, const char *format, ...)

cdef class BaseListFileReader:
    def __cinit__(self, str file_path, bint strip_lines=True, bint skip_empty_lines=True,
                 str encoding='utf-8', str comment_prefix=None, int max_line_length=8192):
        cdef bytes file_path_bytes = file_path.encode('utf-8')
        cdef const char* c_file_path = file_path_bytes

        cdef FILE* test_fp = fopen(c_file_path, b"r")
        if test_fp == NULL:
            raise FileNotFoundError(f"File not found: {file_path}")
        fclose(test_fp)

        self.buffer = PyList_New(0)
        self.file_path = file_path
        self.strip_lines = strip_lines
        self.skip_empty_lines = skip_empty_lines
        self.encoding = encoding
        self.comment_prefix = comment_prefix
        self.max_line_length = max_line_length
        self._is_read = False

    cdef bint _should_skip_line(self, str line):
        if self.skip_empty_lines and not line:
            return True
        if self.comment_prefix is not None and line.startswith(self.comment_prefix):
            return True
        return False

    cpdef void clear(self):
        PyList_SetSlice(self.buffer, 0, PyList_GET_SIZE(self.buffer), [])
        self._is_read = False

    def __len__(self) -> int:
        if not self._is_read:
            self.read()
        return PyList_GET_SIZE(self.buffer)

    def __getitem__(self, index) -> Union[str, List[str]]:
        if not self._is_read:
            self.read()
        return self.buffer[index]

    def __iter__(self) -> Iterator[str]:
        if not self._is_read:
            self.read()
        return iter(self.buffer)

    def __bool__(self) -> bool:
        return len(self) > 0

    def __repr__(self) -> str:
        cdef char repr_buffer[256]
        cdef int buffer_len = PyList_GET_SIZE(self.buffer) if self.buffer else 0

        cdef bytes class_name_bytes = self.__class__.__name__.encode('utf-8')
        cdef const char* class_name_c = class_name_bytes
        cdef bytes file_path_bytes = self.file_path.encode('utf-8')
        cdef const char* file_path_c = file_path_bytes

        PyOS_snprintf(repr_buffer, sizeof(repr_buffer),
                     b"%s('%s', lines=%d)",
                     class_name_c,
                     file_path_c,
                     buffer_len)

        return PyUnicode_FromString(repr_buffer).decode('utf-8')

cdef class ListFileReader(BaseListFileReader):
    cpdef list read(self, bint force_reload=False):
        if self._is_read and not force_reload:
            return self.buffer

        cdef FILE *fp = NULL
        cdef char *line_buffer = NULL
        cdef Py_ssize_t n
        cdef bytes py_bytes
        cdef str line_str
        cdef int lines_read = 0

        line_buffer = <char*>malloc(self.max_line_length)
        if line_buffer == NULL:
            raise MemoryError("Failed to allocate line buffer")

        PyList_SetSlice(self.buffer, 0, PyList_GET_SIZE(self.buffer), [])

        cdef bytes file_path_bytes
        cdef const char* c_file_path

        try:
            file_path_bytes = self.file_path.encode(self.encoding)
            c_file_path = file_path_bytes
            fp = fopen(c_file_path, "r")
            if fp == NULL:
                free(line_buffer)
                raise IOError(f"Could not open file: {self.file_path}")

            try:
                while fgets(line_buffer, self.max_line_length, fp) != NULL:
                    if ferror(fp):
                        raise IOError(f"Error reading from file: {self.file_path}")
                    n = <Py_ssize_t>strlen(line_buffer)
                    if n > 0 and line_buffer[n-1] == '\n':
                        line_buffer[n-1] = 0
                        n -= 1
                    if n > 0 and line_buffer[n-1] == '\r':
                        line_buffer[n-1] = 0
                        n -= 1
                    try:
                        py_bytes = PyBytes_FromStringAndSize(line_buffer, n)
                        line_str = py_bytes.decode(self.encoding)
                    except UnicodeDecodeError as e:
                        raise UnicodeDecodeError(
                            self.encoding, py_bytes, e.start, e.end,
                            f"Line {lines_read + 1}: {e.reason}"
                        )
                    if self.strip_lines:
                        line_str = line_str.strip()
                    if not self._should_skip_line(line_str):
                        PyList_Append(self.buffer, line_str)
                    lines_read += 1
            finally:
                if fp != NULL:
                    fclose(fp)
        finally:
            if line_buffer != NULL:
                free(line_buffer)

        self._is_read = True
        return self.buffer

cdef class ListMMAPFileReader(BaseListFileReader):
    cpdef list read(self, bint force_reload=False):
        if self._is_read and not force_reload:
            return self.buffer

        cdef int fd
        cdef char *mapped
        cdef off_t file_size
        cdef Py_ssize_t i = 0
        cdef Py_ssize_t line_start = 0
        cdef Py_ssize_t line_len
        cdef bytes py_bytes
        cdef str line_str
        cdef int lines_processed = 0

        PyList_SetSlice(self.buffer, 0, PyList_GET_SIZE(self.buffer), [])

        cdef bytes file_path_bytes = self.file_path.encode(self.encoding)
        cdef const char* c_file_path = file_path_bytes
        fd = c_open(c_file_path, O_RDONLY)
        if fd == -1:
            raise IOError(f"Could not open file: {self.file_path}")

        try:
            file_size = lseek(fd, 0, SEEK_END)
            if file_size == -1:
                raise IOError(f"Could not determine file size: {self.file_path}")
            lseek(fd, 0, SEEK_SET)

            if file_size == 0:
                self._is_read = True
                return self.buffer

            mapped = <char*>mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0)
            if mapped == <char*>-1:
                raise IOError(f"Memory mapping failed: {self.file_path}")

            try:
                while i < <Py_ssize_t>file_size:
                    if mapped[i] == b'\n'[0] or i == <Py_ssize_t>(file_size - 1):
                        line_len = i - line_start
                        if i == <Py_ssize_t>(file_size - 1) and mapped[i] != b'\n'[0]:
                            line_len += 1
                        if line_len > 0 and mapped[line_start + line_len - 1] == b'\r'[0]:
                            line_len -= 1
                        if line_len > self.max_line_length:
                            raise ValueError(f"Line {lines_processed + 1} exceeds maximum length: {line_len} > {self.max_line_length}")
                        if line_len > 0:
                            try:
                                py_bytes = PyBytes_FromStringAndSize(mapped + line_start, line_len)
                                line_str = py_bytes.decode(self.encoding)
                            except UnicodeDecodeError as e:
                                raise UnicodeDecodeError(
                                    self.encoding, py_bytes, e.start, e.end,
                                    f"Line {lines_processed + 1}: {e.reason}"
                                )
                        else:
                            line_str = ""
                        if self.strip_lines:
                            line_str = line_str.strip()
                        if not self._should_skip_line(line_str):
                            PyList_Append(self.buffer, line_str)
                        line_start = i + 1
                        lines_processed += 1
                    i += 1
            finally:
                if munmap(mapped, file_size) == -1:
                    import warnings
                    warnings.warn(f"Failed to unmap memory for {self.file_path}")
        finally:
            c_close(fd)

        self._is_read = True
        return self.buffer


def create_list_reader(file_path: str, reader_type: str = "auto", **kwargs) -> BaseListFileReader:
    if reader_type == "auto":
        file_size = os.path.getsize(file_path)
        if file_size < 1024 * 1024:
            reader_type = "standard"
        elif file_size < 100 * 1024 * 1024:
            reader_type = "mmap"
        else:
            reader_type = "mmap"
    
    readers = {
        "standard": ListFileReader,
        "mmap": ListMMAPFileReader,
    }
    
    if reader_type not in readers:
        raise ValueError(f"Unknown reader type: {reader_type}")
        
    return readers[reader_type](file_path, **kwargs)
