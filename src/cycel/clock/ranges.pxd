# cython: language_level=3

cdef extern from "ranges.h":
    object py_datetime_range(object self, object args)
    object py_strftime_range(object self, object args, object kwargs)
