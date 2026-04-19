cdef extern from "clock.h":
    object c_clock_monotonic(object self, object args)
    object c_clock_realtime(object self, object args)
    object c_clock_monotonic_raw(object self, object args)
    object c_clock_monotonic_coarse(object self, object args)
    object c_clock_realtime_coarse(object self, object args)
    object c_clock_generic(object self, object args, object kwargs)
    object c_clock_datetime(object self, object args)
