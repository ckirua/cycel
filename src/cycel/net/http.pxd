cimport cython


@cython.final
cdef class HTTPMethods:
    pass


cdef class HTTPRequest:
    cdef public str url
    cdef public str method
    cdef dict headers
    cdef dict params
    cdef dict data

cdef class HTTPResponse:
    cdef:
        public int status_code
        public dict headers
        public bytes content
        public bint ok

cdef class HTTPClient:
    cdef object _session
    cdef object _connection_event
    cdef object _connector
    cdef bint _handle_cookies
    cdef bint _verify_ssl
    cdef object _proxy
    cpdef bint connected(self)
    cpdef void connect(self)

cpdef bint verify_http_status_code(int status_code) noexcept nogil
