# cython: language_level=3
# bounds-check=False
# wraparound=False
# cdivision=True
"""
Integer timestamp conversion to and from timezone-aware UTC datetimes.

All ``*_to_datetime`` helpers return :class:`datetime.datetime` with
``tzinfo=datetime.timezone.utc``. :func:`change_ts_units` rescales integers
between ``'ns'``, ``'us'``, ``'ms'``, and ``'s'``.
"""
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


cdef:
    int64_t NS_PER_US = 1000
    int64_t NS_PER_MS = 1000000
    int64_t NS_PER_SECOND = 1000000000
    int64_t US_PER_SECOND = 1000000
    int64_t MS_PER_SECOND = 1000
    int64_t SECONDS_PER_MINUTE = 60
    int64_t SECONDS_PER_HOUR = 3600
    int64_t SECONDS_PER_DAY = 86400
    int64_t DAYS_PER_YEAR = 365
    int64_t DAYS_PER_LEAP_YEAR = 366
    # Unix epoch (1970-01-01) as datetime64[ns] for reference
    int64_t DAYS_SINCE_EPOCH_1970 = 719163
    int64_t UNIX_EPOCH_NS = 0


# Time to Datetime
##################
cdef inline object _ns_to_datetime(int64_t ns_timestamp):
    cdef double seconds = ns_timestamp / <double>NS_PER_SECOND
    cdef tuple args = (seconds, <object>PyDateTimeAPI.TimeZone_UTC)
    cdef PyObject* result = PyDateTimeAPI.DateTime_FromTimestamp(
        <PyObject*>PyDateTimeAPI.DateTimeType,
        <PyObject*>args,
        NULL
    )
    if result == NULL:
        raise RuntimeError("Failed to create datetime from timestamp")
    return <object>result


cdef inline object _us_to_datetime(int64_t us_timestamp):
    cdef double seconds = us_timestamp / <double>US_PER_SECOND
    cdef tuple args = (seconds, <object>PyDateTimeAPI.TimeZone_UTC)
    cdef PyObject* result = PyDateTimeAPI.DateTime_FromTimestamp(
        <PyObject*>PyDateTimeAPI.DateTimeType,
        <PyObject*>args,
        NULL
    )
    if result == NULL:
        raise RuntimeError("Failed to create datetime from timestamp")
    return <object>result



cdef inline object _ms_to_datetime(int64_t ms_timestamp):
    cdef double seconds = ms_timestamp / <double>MS_PER_SECOND
    cdef tuple args = (seconds, <object>PyDateTimeAPI.TimeZone_UTC)
    cdef PyObject* result = PyDateTimeAPI.DateTime_FromTimestamp(
        <PyObject*>PyDateTimeAPI.DateTimeType,
        <PyObject*>args,
        NULL
    )
    if result == NULL:
        raise RuntimeError("Failed to create datetime from timestamp")
    return <object>result


cdef inline object _s_to_datetime(int64_t s_timestamp):
    cdef double seconds = <double>s_timestamp
    cdef tuple args = (seconds, <object>PyDateTimeAPI.TimeZone_UTC)
    cdef PyObject* result = PyDateTimeAPI.DateTime_FromTimestamp(
        <PyObject*>PyDateTimeAPI.DateTimeType,
        <PyObject*>args,
        NULL
    )
    if result == NULL:
        raise RuntimeError("Failed to create datetime from timestamp")
    return <object>result


cpdef datetime ns_to_datetime(int64_t ns_timestamp):
    """
    Convert nanoseconds since the Unix epoch to a UTC ``datetime``.

    Args:
        ns_timestamp: Integer nanoseconds (may be negative for pre-1970 times).

    Returns:
        Aware UTC :class:`datetime.datetime`.
    """
    return _ns_to_datetime(ns_timestamp)


cpdef datetime us_to_datetime(int64_t us_timestamp):
    """
    Convert microseconds since the Unix epoch to a UTC ``datetime``.

    Args:
        us_timestamp: Integer microseconds since epoch.

    Returns:
        Aware UTC :class:`datetime.datetime`.
    """
    return _us_to_datetime(us_timestamp)


cpdef datetime ms_to_datetime(int64_t ms_timestamp):
    """
    Convert milliseconds since the Unix epoch to a UTC ``datetime``.

    Args:
        ms_timestamp: Integer milliseconds since epoch.

    Returns:
        Aware UTC :class:`datetime.datetime`.
    """
    return _ms_to_datetime(ms_timestamp)


cpdef datetime s_to_datetime(int64_t s_timestamp):
    """
    Convert whole seconds since the Unix epoch to a UTC ``datetime``.

    Args:
        s_timestamp: Integer seconds since epoch.

    Returns:
        Aware UTC :class:`datetime.datetime` (microsecond field is zero).
    """
    return _s_to_datetime(s_timestamp)


# Datetime to Time
##################
cdef inline int64_t _datetime_to_ns(datetime dt):
    cdef double timestamp = dt.timestamp()
    return <int64_t>(timestamp * NS_PER_SECOND)


cdef inline int64_t _datetime_to_us(datetime dt):
    cdef double timestamp = dt.timestamp()
    return <int64_t>(timestamp * US_PER_SECOND)


cdef inline int64_t _datetime_to_ms(datetime dt):
    cdef double timestamp = dt.timestamp()
    return <int64_t>(timestamp * MS_PER_SECOND)


cdef inline double _datetime_to_s(datetime dt):
    return dt.timestamp()


cpdef int64_t datetime_to_ns(datetime dt):
    """
    Convert ``dt`` to nanoseconds since the Unix epoch (truncated toward zero).

    Args:
        dt: Any ``datetime`` understood by :meth:`datetime.datetime.timestamp`.

    Returns:
        Signed 64-bit nanosecond count.
    """
    return _datetime_to_ns(dt)


cpdef int64_t datetime_to_us(datetime dt):
    """Like :func:`datetime_to_ns` but in microseconds (truncated)."""
    return _datetime_to_us(dt)


cpdef int64_t datetime_to_ms(datetime dt):
    """Like :func:`datetime_to_ns` but in milliseconds (truncated)."""
    return _datetime_to_ms(dt)


cpdef double datetime_to_s(datetime dt):
    """Return :meth:`datetime.datetime.timestamp` as ``float`` seconds."""
    return _datetime_to_s(dt)


# Adjust Timestamp
##################  
cpdef inline int64_t change_ts_units(int64_t timestamp, str from_unit='ns', str to_unit='ns')  except -1 nogil:
    # Rescale integer ``timestamp`` between 'ns', 'us', 'ms', 's'. Raises ValueError for bad units (with gil).
    if from_unit == to_unit:
        return timestamp
    
    # Convert to nanoseconds first
    if from_unit == 'us':
        timestamp = timestamp * NS_PER_US
    elif from_unit == 'ms':
        timestamp = timestamp * NS_PER_MS
    elif from_unit == 's':
        timestamp = timestamp * NS_PER_SECOND
    elif from_unit != 'ns':
        with gil:
            raise ValueError(f"Unsupported from_unit: {from_unit}")
    
    # Convert from nanoseconds to target unit
    if to_unit == 'us':
        return timestamp // NS_PER_US
    elif to_unit == 'ms':
        return timestamp // NS_PER_MS
    elif to_unit == 's':
        return timestamp // NS_PER_SECOND
    elif to_unit == 'ns':
        return timestamp
    else:
        with gil:
            raise ValueError(f"Unsupported to_unit: {to_unit}")