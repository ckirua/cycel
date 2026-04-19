#pragma once

#include <Python.h>
#include <datetime.h>

// datetime_range(start: datetime, end: datetime, step: timedelta) -> list[datetime]
PyObject *py_datetime_range(PyObject *self, PyObject *args);

// strftime_range(start: datetime, end: datetime, step: timedelta, format: str = ...) -> list[str]
PyObject *py_strftime_range(PyObject *self, PyObject *args, PyObject *kwargs);
