cdef class ZMQSocket:
    cdef void* _ctx
    cdef void* _socket
    cdef int _socket_type
    cdef bytes _id
    cdef object _socket_parameters
    cdef public int _fd
    cdef public object _loop
    cdef public object _recv_futures
    cdef public object _send_futures

    cdef int _initialize(self) except -1
    cdef int _close(self) except -1
    cdef bytes _get_url(self)
    cdef int _send_multipart_nowait(self, bytes topic, bytes data) except -1
    cdef int _send_bytes_nowait(self, bytes data) except -1
    cdef list _recv_multipart_nowait(self)


cdef class ZMQPublisher(ZMQSocket):
    pass


cdef class ZMQSubscriber(ZMQSocket):
    pass


cdef class ZMQRouter(ZMQSocket):
    pass


cdef class ZMQDealer(ZMQSocket):
    pass


cdef class ZMQPush(ZMQSocket):
    pass


cdef class ZMQPull(ZMQSocket):
    pass
