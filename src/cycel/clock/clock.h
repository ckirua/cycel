#pragma once

#include <Python.h>
#include <time.h>
#include <stdint.h>

// Returns current monotonic time in nanoseconds (CLOCK_MONOTONIC)
PyObject *c_clock_monotonic(PyObject *self, PyObject *args);

// Returns current realtime in nanoseconds since epoch (CLOCK_REALTIME)
PyObject *c_clock_realtime(PyObject *self, PyObject *args);

// Returns raw monotonic time in nanoseconds (CLOCK_MONOTONIC_RAW)
PyObject *c_clock_monotonic_raw(PyObject *self, PyObject *args);

// Returns coarse monotonic time in nanoseconds (CLOCK_MONOTONIC_COARSE)
PyObject *c_clock_monotonic_coarse(PyObject *self, PyObject *args);

// Returns coarse realtime in nanoseconds (CLOCK_REALTIME_COARSE)
PyObject *c_clock_realtime_coarse(PyObject *self, PyObject *args);

// Generic clock_gettime wrapper: takes clock_id as int, returns nanoseconds
PyObject *c_clock_generic(PyObject *self, PyObject *args, PyObject *kwargs);

// Returns current realtime as a Python datetime object
PyObject *c_clock_datetime(PyObject *self, PyObject *args);
