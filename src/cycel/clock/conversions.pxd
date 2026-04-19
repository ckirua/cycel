# cython: language_level=3
# bounds-check=False
# wraparound=False
# cdivision=True

from cpython cimport PyObject, PyTypeObject
from cpython.datetime cimport PyDateTime_IMPORT, datetime
from libc.stdint cimport int64_t

# Import datetime C API
PyDateTime_IMPORT

cdef extern from "datetime.h":
    ctypedef struct PyDateTime_CAPI:
        PyTypeObject *DateTimeType
        PyTypeObject *DateType
        PyTypeObject *TimeType
        PyTypeObject *DeltaType
        PyTypeObject *TZInfoType
        PyObject *TimeZone_UTC
        PyObject *(*DateTime_FromDateAndTime)(int, int, int, int, int, int, int, PyObject*, PyObject*)
        PyObject *(*DateTime_FromTimestamp)(PyObject*, PyObject*, PyObject*)
        int (*PyDateTime_DATE_GET_MICROSECOND)(PyObject*)
        int (*PyDateTime_DATE_GET_SECOND)(PyObject*)
        int (*PyDateTime_DATE_GET_MINUTE)(PyObject*)
        int (*PyDateTime_DATE_GET_HOUR)(PyObject*)
        int (*PyDateTime_DATE_GET_DAY)(PyObject*)
        int (*PyDateTime_DATE_GET_MONTH)(PyObject*)
        int (*PyDateTime_DATE_GET_YEAR)(PyObject*)

    PyDateTime_CAPI *PyDateTimeAPI

# Constants
cdef:
    int64_t NS_PER_US
    int64_t NS_PER_MS
    int64_t NS_PER_SECOND
    int64_t US_PER_SECOND
    int64_t MS_PER_SECOND
    int64_t SECONDS_PER_MINUTE
    int64_t SECONDS_PER_HOUR
    int64_t SECONDS_PER_DAY
    int64_t DAYS_PER_YEAR
    int64_t DAYS_PER_LEAP_YEAR
    int64_t DAYS_SINCE_EPOCH_1970
    int64_t UNIX_EPOCH_NS

# Internal conversion functions
cdef object _ns_to_datetime(int64_t ns_timestamp)
cdef object _us_to_datetime(int64_t us_timestamp)
cdef object _ms_to_datetime(int64_t ms_timestamp)
cdef object _s_to_datetime(int64_t s_timestamp)

cdef int64_t _datetime_to_ns(datetime dt)
cdef int64_t _datetime_to_us(datetime dt)
cdef int64_t _datetime_to_ms(datetime dt)
cdef double _datetime_to_s(datetime dt)

# Public API
cpdef datetime ns_to_datetime(int64_t ns_timestamp)
cpdef datetime us_to_datetime(int64_t us_timestamp)
cpdef datetime ms_to_datetime(int64_t ms_timestamp)
cpdef datetime s_to_datetime(int64_t s_timestamp)

cpdef int64_t datetime_to_ns(datetime dt)
cpdef int64_t datetime_to_us(datetime dt)
cpdef int64_t datetime_to_ms(datetime dt)
cpdef double datetime_to_s(datetime dt)

cpdef int64_t change_ts_units(int64_t timestamp, str from_unit=*, str to_unit=*) except -1 nogil