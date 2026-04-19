from libc.stdio cimport sscanf
from libc.string cimport strchr


cdef extern from "time.h":
    ctypedef struct tm:
        int tm_sec
        int tm_min
        int tm_hour
        int tm_mday
        int tm_mon
        int tm_year
        int tm_wday
        int tm_yday
        int tm_isdst
    ctypedef long time_t
    time_t timegm(tm* t)


cdef int get_month_num(const char* month) except -1 nogil