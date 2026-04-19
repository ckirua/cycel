#pragma once    

#include <Python.h>
#include <datetime.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations of types
typedef struct {
    PyObject_HEAD
    int year, month, day, hour, minute, second, usec;
    int step_days, step_secs, step_usecs;
    PyObject *end;
    PyObject *tzinfo;
    const char *fmt;
} StrfTimeIteratorObject;

typedef struct {
    PyObject_HEAD
    int year, month, day;
    int hour, minute, second, usec;
    int step_days, step_secs, step_usecs;
    PyObject *end;
    PyObject *tzinfo;
} DateTimeIteratorObject;

// Extern declarations for type objects
extern PyTypeObject StrfTimeIteratorType;
extern PyTypeObject DateTimeIteratorType;

// Module init function
PyMODINIT_FUNC PyInit_iterators(void);

#ifdef __cplusplus
}
#endif
