#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

// datetime_range(start, end, step)
PyObject *py_datetime_range(PyObject *self, PyObject *args) {
  PyObject *start, *end, *step;
  if (!PyArg_ParseTuple(args, "OOO", &start, &end, &step))
    return NULL;

  if (!PyDateTime_Check(start) || !PyDateTime_Check(end) ||
      !PyDelta_Check(step)) {
    PyErr_SetString(PyExc_TypeError, "Expected datetime, datetime, timedelta");
    return NULL;
  }

  PyObject *step_sec_obj = PyObject_CallMethod(step, "total_seconds", NULL);
  if (!step_sec_obj)
    return NULL;
  double step_seconds = PyFloat_AsDouble(step_sec_obj);
  Py_DECREF(step_sec_obj);

  if (step_seconds <= 0.0) {
    return PyList_New(0);
  }

  PyObject *diff = PyNumber_Subtract(end, start);
  if (!diff)
    return NULL;
  PyObject *diff_sec_obj = PyObject_CallMethod(diff, "total_seconds", NULL);
  Py_DECREF(diff);
  if (!diff_sec_obj)
    return NULL;
  double total_seconds = PyFloat_AsDouble(diff_sec_obj);
  Py_DECREF(diff_sec_obj);

  if (total_seconds < 0) {
    return PyList_New(0);
  }

  long n = (long)(total_seconds / step_seconds) + 1;
  if (n <= 0)
    return PyList_New(0);

  PyObject *list = PyList_New(n);
  if (!list)
    return NULL;

  PyObject *current = start;
  Py_INCREF(current);

  for (long i = 0; i < n; i++) {
    Py_INCREF(current);
    PyList_SET_ITEM(list, i, current);

    PyObject *new_current = PyNumber_Add(current, step);
    if (!new_current) {
      Py_DECREF(current);
      Py_DECREF(list);
      return NULL;
    }
    Py_DECREF(current);
    current = new_current;
  }
  Py_DECREF(current);

  return list;
}

// strftime_range(start, end, step, format)
PyObject *py_strftime_range(PyObject *self, PyObject *args, PyObject *kwargs) {
  static char *kwlist[] = {"start", "end", "step", "format", NULL};
  PyObject *start, *end, *step;
  const char *format = "%Y-%m-%d %H:%M:%S";

  if (!PyArg_ParseTupleAndKeywords(args, kwargs, "OOO|s", kwlist, &start, &end,
                                   &step, &format))
    return NULL;

  if (!PyDateTime_Check(start) || !PyDateTime_Check(end) ||
      !PyDelta_Check(step)) {
    PyErr_SetString(PyExc_TypeError, "Expected datetime, datetime, timedelta");
    return NULL;
  }

  PyObject *step_sec_obj = PyObject_CallMethod(step, "total_seconds", NULL);
  if (!step_sec_obj)
    return NULL;
  double step_seconds = PyFloat_AsDouble(step_sec_obj);
  Py_DECREF(step_sec_obj);

  if (step_seconds <= 0.0) {
    return PyList_New(0);
  }

  PyObject *diff = PyNumber_Subtract(end, start);
  if (!diff)
    return NULL;
  PyObject *diff_sec_obj = PyObject_CallMethod(diff, "total_seconds", NULL);
  Py_DECREF(diff);
  if (!diff_sec_obj)
    return NULL;
  double total_seconds = PyFloat_AsDouble(diff_sec_obj);
  Py_DECREF(diff_sec_obj);

  if (total_seconds < 0) {
    return PyList_New(0);
  }

  long n = (long)(total_seconds / step_seconds) + 1;
  if (n <= 0)
    return PyList_New(0);

  PyObject *list = PyList_New(n);
  if (!list)
    return NULL;

  PyObject *current = start;
  Py_INCREF(current);

  for (long i = 0; i < n; i++) {
    PyObject *s = PyObject_CallMethod(current, "strftime", "s", format);
    if (!s) {
      Py_DECREF(current);
      Py_DECREF(list);
      return NULL;
    }
    PyList_SET_ITEM(list, i, s);

    PyObject *new_current = PyNumber_Add(current, step);
    if (!new_current) {
      Py_DECREF(current);
      Py_DECREF(list);
      return NULL;
    }
    Py_DECREF(current);
    current = new_current;
  }
  Py_DECREF(current);

  return list;
}

static PyMethodDef RangesMethods[] = {
    {"datetime_range", (PyCFunction)py_datetime_range, METH_VARARGS,
     "datetime_range(start, end, step) -> list[datetime]\n--\n\n"
     "Inclusive list from ``start`` to ``end`` stepping by ``step``; empty if step <= 0 or end < start."},
    {"strftime_range", (PyCFunction)py_strftime_range,
     METH_VARARGS | METH_KEYWORDS,
     "strftime_range(start, end, step, format='%Y-%m-%d %H:%M:%S') -> list[str]\n--\n\n"
     "Like :func:`datetime_range` but each element is ``dt.strftime(format)``."},
    {NULL, NULL, 0, NULL}};

static struct PyModuleDef rangesmodule = {
    PyModuleDef_HEAD_INIT, "ranges",
    "Materialized datetime / strftime sequences (``cycel.clock``).", -1,
    RangesMethods};

PyMODINIT_FUNC PyInit_ranges(void) {
  PyDateTime_IMPORT;
  return PyModule_Create(&rangesmodule);
}
