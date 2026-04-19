from cpython.dict cimport PyDict_New, PyDict_SetItem
from cpython.list cimport PyList_Append, PyList_New
from cpython.unicode cimport (PyUnicode_AsUTF8String,
                              PyUnicode_FromStringAndSize)
from libc.stdio cimport FILE
from libc.stdlib cimport free, realloc
from libc.string cimport memcpy


cdef parse_json_string(const char* str_start, const char** end_ptr)
cdef parse_json_number(const char* str_start, const char** end_ptr)
cdef parse_json_value(const char* str_start, const char** end_ptr)
cdef dict parse_json_object(const char* str_start, const char** end_ptr)
cdef list parse_json_array(const char* str_start, const char** end_ptr)
cdef object parse_json_file(FILE* cfile)
cdef write_json_value(FILE* cfile, object value, int indent)  # Remove except -1 for Python objects

cpdef read_json(str file_path)
cpdef write_json(str file_path, object data)
