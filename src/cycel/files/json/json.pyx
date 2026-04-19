# cython: language_level=3
# cython: wraparound=False
from cpython.dict cimport PyDict_New, PyDict_SetItem
from cpython.list cimport PyList_Append, PyList_New
from cpython.unicode cimport (PyUnicode_AsUTF8String,
                              PyUnicode_FromStringAndSize)
from libc.stdio cimport FILE, fclose, feof, fgets, fopen, fprintf
from libc.stdlib cimport free, realloc, strtod, strtol
from libc.string cimport memcpy, strchr, strlen, strncmp

DEF MAX_LINE_LENGTH = 4096  # JSON can have longer lines

cdef enum JsonState:
    OBJECT_START
    OBJECT_KEY
    OBJECT_COLON
    OBJECT_VALUE
    ARRAY_START
    ARRAY_VALUE
    EXPECT_COMMA_OR_END

cdef parse_json_string(const char* str_start, const char** end_ptr):
    cdef const char* ptr = str_start + 1  # Skip opening quote
    cdef const char* start = ptr
    cdef int length = 0
    cdef int prev_is_backslash = 0
    
    while True:
        if ptr[0] == b'\0':
            raise ValueError("Unterminated string")
            
        if ptr[0] == b'"' and not prev_is_backslash:
            break
            
        prev_is_backslash = (ptr[0] == b'\\' and not prev_is_backslash)
        ptr += 1
        length += 1
    
    end_ptr[0] = ptr + 1  # Point to after closing quote
    return PyUnicode_FromStringAndSize(start, length)

cdef parse_json_number(const char* str_start, const char** end_ptr):
    cdef char* endptr
    cdef double dval = strtod(str_start, &endptr)
    
    # Check if it's actually a float
    if strchr(str_start, b'.') != NULL or strchr(str_start, b'e') != NULL or strchr(str_start, b'E') != NULL:
        end_ptr[0] = endptr
        return dval
    
    # Try parsing as integer
    cdef long ival = strtol(str_start, &endptr, 10)
    end_ptr[0] = endptr
    return ival

cdef parse_json_value(const char* str_start, const char** end_ptr):
    cdef const char* ptr = str_start
    
    # Skip whitespace
    while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
        ptr += 1
    
    if ptr[0] == b'{':
        return parse_json_object(ptr, end_ptr)
    elif ptr[0] == b'[':
        return parse_json_array(ptr, end_ptr)
    elif ptr[0] == b'"':
        return parse_json_string(ptr, end_ptr)
    elif strncmp(ptr, "true", 4) == 0:
        end_ptr[0] = ptr + 4
        return True
    elif strncmp(ptr, "false", 5) == 0:
        end_ptr[0] = ptr + 5
        return False
    elif strncmp(ptr, "null", 4) == 0:
        end_ptr[0] = ptr + 4
        return None
    elif (ptr[0] >= b'0' and ptr[0] <= b'9') or ptr[0] == b'-':
        return parse_json_number(ptr, end_ptr)
    else:
        raise ValueError(f"Unexpected character: {chr(ptr[0])}")

cdef dict parse_json_object(const char* str_start, const char** end_ptr):
    cdef dict obj = PyDict_New()
    cdef const char* ptr = str_start + 1  # Skip '{'
    cdef str key
    cdef object value
    
    while True:
        # Skip whitespace
        while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
            ptr += 1
        
        if ptr[0] == b'}':
            end_ptr[0] = ptr + 1
            return obj
        
        # Parse key
        if ptr[0] != b'"':
            raise ValueError("Expected string key in object")
        
        key = parse_json_string(ptr, &ptr)
        
        # Skip whitespace
        while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
            ptr += 1
        
        # Expect colon
        if ptr[0] != b':':
            raise ValueError("Expected ':' after key")
        ptr += 1
        
        # Parse value
        value = parse_json_value(ptr, &ptr)
        PyDict_SetItem(obj, key, value)
        
        # Skip whitespace
        while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
            ptr += 1
        
        # Check for comma or end
        if ptr[0] == b',':
            ptr += 1
        elif ptr[0] != b'}':
            raise ValueError("Expected ',' or '}' in object")

cdef list parse_json_array(const char* str_start, const char** end_ptr):
    cdef list array = PyList_New(0)
    cdef const char* ptr = str_start + 1  # Skip '['
    cdef object value
    
    while True:
        # Skip whitespace
        while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
            ptr += 1
        
        if ptr[0] == b']':
            end_ptr[0] = ptr + 1
            return array
        
        # Parse value
        value = parse_json_value(ptr, &ptr)
        PyList_Append(array, value)
        
        # Skip whitespace
        while ptr[0] == b' ' or ptr[0] == b'\t' or ptr[0] == b'\n' or ptr[0] == b'\r':
            ptr += 1
        
        # Check for comma or end
        if ptr[0] == b',':
            ptr += 1
        elif ptr[0] != b']':
            raise ValueError("Expected ',' or ']' in array")

cdef object parse_json_file(FILE* cfile):
    cdef:
        char[MAX_LINE_LENGTH] buffer
        char* json_str = NULL
        size_t json_len = 0
        const char* end_ptr
        object result
        size_t line_len
    
    # Read entire file into memory (JSON needs full parsing, not line-by-line)
    while not feof(cfile):
        if fgets(buffer, MAX_LINE_LENGTH, cfile) == NULL:
            break
        
        # Skip comments (non-standard but sometimes present)
        if buffer[0] == b'/' and (buffer[1] == b'/' or buffer[1] == b'*'):
            continue
        
        # Reallocate and append to json_str
        # (In a real implementation, you'd want to use a more efficient buffer growth strategy)
        line_len = strlen(buffer)
        json_str = <char*>realloc(json_str, json_len + line_len + 1)
        memcpy(json_str + json_len, buffer, line_len)
        json_len += line_len
    
    if json_str == NULL:
        raise ValueError("Empty JSON file")
    
    json_str[json_len] = b'\0'
    
    try:
        result = parse_json_value(json_str, &end_ptr)
        
        # Check for trailing content
        while end_ptr[0] == b' ' or end_ptr[0] == b'\t' or end_ptr[0] == b'\n' or end_ptr[0] == b'\r':
            end_ptr += 1
        if end_ptr[0] != b'\0':
            raise ValueError("Trailing content after JSON value")
        
        return result
    finally:
        if json_str != NULL:
            free(json_str)

cpdef read_json(str file_path):
    cdef:
        FILE* cfile
        object result
    
    cfile = fopen(file_path.encode('utf-8'), "r")
    if cfile == NULL:
        raise FileNotFoundError(f"Could not open file: {file_path}")
    
    try:
        result = parse_json_file(cfile)
    finally:
        fclose(cfile)
    
    return result


cdef write_json_value(FILE* cfile, object value, int indent):
    cdef:
        str indent_str = "    " * indent
        str key
        object item
        int i, size
        bytes value_bytes, key_bytes, indent_bytes
        double float_val
    
    if value is None:
        fprintf(cfile, b"null")
    elif isinstance(value, bool):
        if value:
            fprintf(cfile, b"true")
        else:
            fprintf(cfile, b"false")
    elif isinstance(value, (int, float)):
        # Handle both int and float using %g format
        float_val = float(value)
        fprintf(cfile, b"%g", float_val)
    elif isinstance(value, str):
        # Escape special characters and wrap in quotes
        value_bytes = PyUnicode_AsUTF8String(value)
        fprintf(cfile, b"\"%s\"", value_bytes)
    elif isinstance(value, dict):
        fprintf(cfile, b"{\n")
        size = len(value)
        indent_bytes = indent_str.encode('utf-8')
        for i, (key, item) in enumerate(value.items()):
            key_bytes = key.encode('utf-8')
            fprintf(cfile, b"%s\"%s\": ", indent_bytes, key_bytes)
            write_json_value(cfile, item, indent + 1)
            if i < size - 1:
                fprintf(cfile, b",\n")
            else:
                fprintf(cfile, b"\n")
        fprintf(cfile, b"%s}", indent_bytes)
    elif isinstance(value, list):
        fprintf(cfile, b"[\n")
        size = len(value)
        indent_bytes = indent_str.encode('utf-8')
        for i in range(size):
            item = value[i]
            fprintf(cfile, b"%s", indent_bytes)
            write_json_value(cfile, item, indent + 1)
            if i < size - 1:
                fprintf(cfile, b",\n")
            else:
                fprintf(cfile, b"\n")
        fprintf(cfile, b"%s]", indent_bytes)
    else:
        raise TypeError(f"Object of type {type(value)} is not JSON serializable")

cpdef write_json(str file_path, object data):
    cdef:
        FILE* cfile
    
    cfile = fopen(file_path.encode('utf-8'), "w")
    if cfile == NULL:
        raise FileNotFoundError(f"Could not open file for writing: {file_path}")
    
    try:
        write_json_value(cfile, data, 0)
        fprintf(cfile, b"\n")
    finally:
        fclose(cfile)