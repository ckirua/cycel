cdef extern from "zmq.h" nogil:
    void* zmq_ctx_new()
    int zmq_ctx_destroy(void* context)

    void* zmq_socket(void* context, int type)
    int zmq_close(void* socket)
    int zmq_bind(void* socket, const char* endpoint)
    int zmq_connect(void* socket, const char* endpoint)
    int zmq_disconnect(void* socket, const char* endpoint)
    int zmq_setsockopt(void* socket, int option_name, const void* option_value, size_t option_len)
    int zmq_getsockopt(void* socket, int option_name, void* option_value, size_t* option_len)

    ctypedef struct zmq_msg_t:
        unsigned char _[64]

    int zmq_msg_init(zmq_msg_t* msg)
    int zmq_msg_init_size(zmq_msg_t* msg, size_t size)
    int zmq_msg_init_data(zmq_msg_t* msg, void* data, size_t size, void* ffn, void* hint)
    int zmq_msg_send(zmq_msg_t* msg, void* socket, int flags)
    int zmq_msg_recv(zmq_msg_t* msg, void* socket, int flags)
    int zmq_msg_close(zmq_msg_t* msg)
    void* zmq_msg_data(zmq_msg_t* msg)
    size_t zmq_msg_size(zmq_msg_t* msg)

    enum: ZMQ_FD
    enum: ZMQ_EVENTS
    enum: ZMQ_POLLIN
    enum: ZMQ_POLLOUT

    enum: ZMQ_SNDMORE
    enum: ZMQ_DONTWAIT
    enum: ZMQ_RCVMORE

    enum: ZMQ_PUB
    enum: ZMQ_SUB
    enum: ZMQ_ROUTER
    enum: ZMQ_DEALER
    enum: ZMQ_PUSH
    enum: ZMQ_PULL

    enum: ZMQ_SUBSCRIBE
    enum: ZMQ_IDENTITY
    enum: ZMQ_RCVTIMEO
    enum: ZMQ_SNDTIMEO
    enum: ZMQ_LINGER
    enum: ZMQ_SNDHWM
    enum: ZMQ_RCVHWM

    int zmq_errno()
    const char* zmq_strerror(int errnum)