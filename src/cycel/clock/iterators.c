#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>
#include <time.h>

// ============================================================================
// StrfTimeIterator
// ============================================================================

typedef struct {
    PyObject_HEAD
    int year, month, day, hour, minute, second, usec;
    int step_days, step_secs, step_usecs;
    PyObject *end;
    PyObject *tzinfo;
    const char *fmt;
} StrfTimeIteratorObject;

static inline void normalize_datetime(
    int *year, int *month, int *day,
    int *hour, int *minute, int *second, int *usec,
    int add_days, int add_secs, int add_usecs
) {
    struct tm t = {0};
    t.tm_year = *year - 1900;
    t.tm_mon  = *month - 1;
    t.tm_mday = *day;
    t.tm_hour = *hour;
    t.tm_min  = *minute;
    t.tm_sec  = *second;

    long total_usecs = *usec + add_usecs;
    int carry_sec = total_usecs / 1000000;
    *usec = total_usecs % 1000000;
    if (*usec < 0) { *usec += 1000000; carry_sec--; }

    time_t base = timegm(&t);
    base += add_days * 86400 + add_secs + carry_sec;

    struct tm nt;
    gmtime_r(&base, &nt);

    *year   = nt.tm_year + 1900;
    *month  = nt.tm_mon + 1;
    *day    = nt.tm_mday;
    *hour   = nt.tm_hour;
    *minute = nt.tm_min;
    *second = nt.tm_sec;
}

static PyObject *StrfTimeIterator_iter(PyObject *self) {
    Py_INCREF(self);
    return self;
}

static PyObject *StrfTimeIterator_next(PyObject *self) {
    StrfTimeIteratorObject *obj = (StrfTimeIteratorObject *)self;

    PyObject *dt = PyDateTimeAPI->DateTime_FromDateAndTime(
        obj->year, obj->month, obj->day,
        obj->hour, obj->minute, obj->second,
        obj->usec, obj->tzinfo, PyDateTimeAPI->DateTimeType
    );
    if (!dt) return NULL;

    int cmp = PyObject_RichCompareBool(dt, obj->end, Py_GT);
    if (cmp == -1) { Py_DECREF(dt); return NULL; }
    if (cmp) { Py_DECREF(dt); PyErr_SetNone(PyExc_StopIteration); return NULL; }

    PyObject *s = PyObject_CallMethod(dt, "strftime", "s", obj->fmt);
    Py_DECREF(dt);
    if (!s) return NULL;

    Py_BEGIN_ALLOW_THREADS
    normalize_datetime(
        &obj->year, &obj->month, &obj->day,
        &obj->hour, &obj->minute, &obj->second, &obj->usec,
        obj->step_days, obj->step_secs, obj->step_usecs
    );
    Py_END_ALLOW_THREADS

    return s;
}

static int StrfTimeIterator_init(StrfTimeIteratorObject *self, PyObject *args, PyObject *kwds) {
    static char *kwlist[] = {"start","end","step","format",NULL};
    PyObject *start, *end, *step;
    const char *fmt = "%Y-%m-%d %H:%M:%S";

    if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOO|s", kwlist,
                                     &start, &end, &step, &fmt))
        return -1;
    if (!PyDateTime_Check(start) || !PyDateTime_Check(end) || !PyDelta_Check(step)) {
        PyErr_SetString(PyExc_TypeError, "Expected datetime, datetime, timedelta");
        return -1;
    }

    PyDateTime_DateTime *dt = (PyDateTime_DateTime*)start;
    self->year   = PyDateTime_GET_YEAR(dt);
    self->month  = PyDateTime_GET_MONTH(dt);
    self->day    = PyDateTime_GET_DAY(dt);
    self->hour   = PyDateTime_DATE_GET_HOUR(dt);
    self->minute = PyDateTime_DATE_GET_MINUTE(dt);
    self->second = PyDateTime_DATE_GET_SECOND(dt);
    self->usec   = PyDateTime_DATE_GET_MICROSECOND(dt);
    self->tzinfo = PyDateTime_DATE_GET_TZINFO(dt);
    Py_XINCREF(self->tzinfo);

    self->step_days  = ((PyDateTime_Delta*)step)->days;
    self->step_secs  = ((PyDateTime_Delta*)step)->seconds;
    self->step_usecs = ((PyDateTime_Delta*)step)->microseconds;

    self->end = end;
    Py_INCREF(end);

    self->fmt = fmt;

    return 0;
}

static void StrfTimeIterator_dealloc(StrfTimeIteratorObject *self) {
    Py_XDECREF(self->tzinfo);
    Py_XDECREF(self->end);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

PyTypeObject StrfTimeIteratorType = {
    PyVarObject_HEAD_INIT(NULL,0)
    .tp_name = "iterators.StrfTimeIterator",
    .tp_basicsize = sizeof(StrfTimeIteratorObject),
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "StrfTimeIterator(start, end, step, format='%Y-%m-%d %H:%M:%S')\n"
              "--\n\n"
              "Iterator yielding ``start.strftime(format)`` advancing by ``step`` until ``end`` is exceeded.",
    .tp_iter = StrfTimeIterator_iter,
    .tp_iternext = StrfTimeIterator_next,
    .tp_init = (initproc)StrfTimeIterator_init,
    .tp_dealloc = (destructor)StrfTimeIterator_dealloc,
    .tp_new = PyType_GenericNew,
};

// ============================================================================
// DateTimeIterator
// ============================================================================

typedef struct {
    PyObject_HEAD
    int year, month, day;
    int hour, minute, second, usec;
    int step_days, step_secs, step_usecs;
    PyObject *end;
    PyObject *tzinfo;
} DateTimeIteratorObject;

// Iterator __iter__ just returns self
static PyObject *DateTimeIterator_iter(PyObject *self) {
    Py_INCREF(self);
    return self;
}

// Iterator __next__
static PyObject *DateTimeIterator_next(PyObject *self) {
    DateTimeIteratorObject *obj = (DateTimeIteratorObject *)self;

    PyObject *current = PyDateTimeAPI->DateTime_FromDateAndTime(
        obj->year, obj->month, obj->day,
        obj->hour, obj->minute, obj->second,
        obj->usec, obj->tzinfo, PyDateTimeAPI->DateTimeType
    );
    if (!current) return NULL;

    // Check if current > end
    int cmp = PyObject_RichCompareBool(current, obj->end, Py_GT);
    if (cmp == -1) {
        Py_DECREF(current);
        return NULL;
    }
    if (cmp) {
        Py_DECREF(current);
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }

    // Advance to next datetime
    Py_BEGIN_ALLOW_THREADS
    normalize_datetime(
        &obj->year, &obj->month, &obj->day,
        &obj->hour, &obj->minute, &obj->second, &obj->usec,
        obj->step_days, obj->step_secs, obj->step_usecs
    );
    Py_END_ALLOW_THREADS

    return current;
}

// __init__
static int DateTimeIterator_init(DateTimeIteratorObject *self, PyObject *args, PyObject *kwds) {
    PyObject *start, *end, *step;
    if (!PyArg_ParseTuple(args, "OOO", &start, &end, &step)) return -1;
    if (!PyDateTime_Check(start) || !PyDateTime_Check(end) || !PyDelta_Check(step)) {
        PyErr_SetString(PyExc_TypeError, "Expected datetime, datetime, timedelta");
        return -1;
    }

    PyDateTime_DateTime *dt = (PyDateTime_DateTime*)start;
    self->year   = PyDateTime_GET_YEAR(dt);
    self->month  = PyDateTime_GET_MONTH(dt);
    self->day    = PyDateTime_GET_DAY(dt);
    self->hour   = PyDateTime_DATE_GET_HOUR(dt);
    self->minute = PyDateTime_DATE_GET_MINUTE(dt);
    self->second = PyDateTime_DATE_GET_SECOND(dt);
    self->usec   = PyDateTime_DATE_GET_MICROSECOND(dt);
    self->tzinfo = PyDateTime_DATE_GET_TZINFO(dt);
    Py_XINCREF(self->tzinfo);

    self->step_days  = ((PyDateTime_Delta*)step)->days;
    self->step_secs  = ((PyDateTime_Delta*)step)->seconds;
    self->step_usecs = ((PyDateTime_Delta*)step)->microseconds;

    self->end = end;
    Py_INCREF(end);

    return 0;
}

// __dealloc__
static void DateTimeIterator_dealloc(DateTimeIteratorObject *self) {
    Py_XDECREF(self->tzinfo);
    Py_XDECREF(self->end);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

PyTypeObject DateTimeIteratorType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "iterators.DateTimeIterator",
    .tp_basicsize = sizeof(DateTimeIteratorObject),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "DateTimeIterator(start, end, step)\n--\n\n"
              "Iterator yielding ``datetime`` values from ``start`` to ``end`` inclusive by ``step``.",
    .tp_iter = DateTimeIterator_iter,
    .tp_iternext = DateTimeIterator_next,
    .tp_init = (initproc)DateTimeIterator_init,
    .tp_dealloc = (destructor)DateTimeIterator_dealloc,
    .tp_new = PyType_GenericNew,
};

// ============================================================================
// Module initialization
// ============================================================================

static PyMethodDef IteratorsMethods[] = {
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef iterators_module = {
    PyModuleDef_HEAD_INIT,
    "iterators",
    "Fast stepping iterators over datetime ranges (``cycel.clock``).",
    -1,
    IteratorsMethods
};

PyMODINIT_FUNC PyInit_iterators(void) {
    PyDateTime_IMPORT;
    
    if (PyType_Ready(&StrfTimeIteratorType) < 0) return NULL;
    if (PyType_Ready(&DateTimeIteratorType) < 0) return NULL;

    PyObject *m = PyModule_Create(&iterators_module);
    if (!m) return NULL;

    Py_INCREF(&StrfTimeIteratorType);
    Py_INCREF(&DateTimeIteratorType);
    
    PyModule_AddObject(m, "StrfTimeIterator", (PyObject *)&StrfTimeIteratorType);
    PyModule_AddObject(m, "DateTimeIterator", (PyObject *)&DateTimeIteratorType);
    
    return m;
}
