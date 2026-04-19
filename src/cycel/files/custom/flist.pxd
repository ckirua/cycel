cdef class BaseListFileReader:
    cdef:
        public list buffer
        public str file_path
        public bint strip_lines
        public bint skip_empty_lines
        public str encoding
        public str comment_prefix
        public int max_line_length
        public bint _is_read

    cdef bint _should_skip_line(self, str line)
    cpdef void clear(self)

cdef class ListFileReader(BaseListFileReader):
    cpdef list read(self, bint force_reload=*)

cdef class ListMMAPFileReader(BaseListFileReader):
    cpdef list read(self, bint force_reload=*)

