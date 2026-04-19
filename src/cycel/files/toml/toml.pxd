from libc.stdio cimport FILE


cdef dict parse_toml_file(FILE* cfile)
cdef object parse_value(const char* value_str)
cdef object parse_array(const char* value_str)
cdef object parse_string(const char* value_str, int length)
cdef int write_value(FILE* cfile, object value, int indent_level) except -1
cdef int write_section(FILE* cfile, dict data, int indent_level, bytes section_name) except -1
