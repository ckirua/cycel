# cython: language_level=3

from cpython.object cimport PyTypeObject

cdef extern from "iterators.h":
    PyTypeObject StrfTimeIteratorType
    PyTypeObject DateTimeIteratorType
