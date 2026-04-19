# cython: language_level=3

from cpython.dict cimport (PyDict_Contains, PyDict_New, PyDict_Next,
                           PyDict_SetItem)
from cpython.list cimport PyList_Check, PyList_GetItem, PyList_Size
from cpython.object cimport PyObject, PyObject_Str
from cpython.unicode cimport (PyUnicode_AsUTF8String, PyUnicode_Check,
                              PyUnicode_FromString)
from libc.stdio cimport FILE, fclose, feof, fgets, fopen, fprintf
from libc.stdlib cimport strtod
from libc.string cimport strchr, strlen, strncmp

DEF MAX_LINE_LENGTH = 1024
DEF MAX_NESTING = 10

cdef parse_string(const char* value_str, int length):
    """
    Remove quotes and return the string content
    """
    cdef:
        const char* start = value_str
        const char* end = value_str + length
        int actual_length = length
        
    # Skip opening quote if present
    if start[0] == b'"':
        start += 1
        actual_length -= 1
        
    # Remove closing quote if present
    if actual_length > 0 and value_str[length - 1] == b'"':
        actual_length -= 1
        
    return PyUnicode_FromString(start)[:actual_length]

cdef parse_array(const char* value_str):
    """
    Parse a TOML array from a string
    """
    cdef:
        list result = []
        const char* p = value_str + 1  # Skip opening '['
        const char* end
        char* endptr
        double dval
        int in_string = 0
        int array_depth = 1
        const char* value_start
        int value_len
        int nested_array_depth
        int escaped = 0
        
    while p[0] != b'\0' and array_depth > 0:
        # Skip whitespace
        while p[0] == b' ' or p[0] == b'\t' or p[0] == b'\n' or p[0] == b'\r':
            p += 1
            
        if p[0] == b']' and not in_string:
            array_depth -= 1
            if array_depth == 0:
                break
            p += 1
            continue
            
        if p[0] == b'[' and not in_string:
            # Start of nested array
            nested_array_depth = 1
            value_start = p
            p += 1
            while nested_array_depth > 0 and p[0] != b'\0':
                if p[0] == b'"':
                    if not escaped:
                        in_string = not in_string
                elif not in_string:
                    if p[0] == b'[':
                        nested_array_depth += 1
                    elif p[0] == b']':
                        nested_array_depth -= 1
                
                escaped = (p[0] == b'\\' and not escaped)
                p += 1
                
            if p[0] != b'\0':
                value_len = p - value_start
                result.append(parse_array(value_start))
                
        elif p[0] == b'"':
            # String value
            value_start = p
            p += 1  # Skip opening quote
            escaped = 0
            
            while p[0] != b'\0':
                if p[0] == b'"' and not escaped:
                    break
                escaped = (p[0] == b'\\' and not escaped)
                p += 1
                
            if p[0] == b'"':
                p += 1  # Skip closing quote
                result.append(parse_string(value_start, p - value_start))
            
        elif p[0] == b't' and strncmp(p, b"true", 4) == 0:
            result.append(True)
            p += 4
            
        elif p[0] == b'f' and strncmp(p, b"false", 5) == 0:
            result.append(False)
            p += 5
            
        else:
            # Try parsing as number
            value_start = p
            dval = strtod(p, &endptr)
            if endptr != p:
                p = endptr
                # Check if it's actually a float
                if strchr(value_start, b'.') != NULL or strchr(value_start, b'e') != NULL or strchr(value_start, b'E') != NULL:
                    result.append(dval)
                else:
                    result.append(int(dval))
            else:
                # Skip until next comma or end of array
                while p[0] != b'\0' and p[0] != b',' and p[0] != b']':
                    p += 1
                
        # Skip to next value
        while p[0] != b'\0' and p[0] != b',' and p[0] != b']':
            p += 1
        if p[0] == b',':
            p += 1
            in_string = 0  # Reset string state after comma
            
    return result

cdef parse_value(const char* value_str):
    """
    Parse a value from a string
    """
    cdef int length = strlen(value_str)
    cdef const char* trimmed = value_str
    
    # Trim leading whitespace
    while trimmed[0] == b' ' and length > 0:
        trimmed += 1
        length -= 1
    
    # Check for boolean
    if strncmp(trimmed, "true", 4) == 0:
        return True
    elif strncmp(trimmed, "false", 5) == 0:
        return False
    
    # Check for arrays
    if trimmed[0] == b'[':
        return parse_array(trimmed)
    
    # Check for numbers
    cdef char* endptr
    cdef double dval = strtod(trimmed, &endptr)
    if endptr != trimmed:
        # Check if it's actually a float
        if strchr(trimmed, b'.') != NULL or strchr(trimmed, b'e') != NULL or strchr(trimmed, b'E') != NULL:
            return dval
        return int(dval)
    
    # Handle strings
    return parse_string(trimmed, length)

cdef dict parse_toml_file(FILE* cfile):
    """
    Parse a TOML file into a dictionary
    """
    cdef:
        char[MAX_LINE_LENGTH] line
        dict current_section = PyDict_New()
        dict root = current_section
        char* key
        char* value
        char* equal_pos
        int key_len
        char* section_name
        dict section_dict
        char* closing_bracket
        int value_len
        char* dot_pos
        char* section_part
        dict parent_dict
        dict temp_dict
    
    while not feof(cfile):
        if fgets(line, MAX_LINE_LENGTH, cfile) == NULL:
            break
        
        # Skip comments and empty lines
        if line[0] == b'#' or line[0] == b'\n':
            continue
        
        # Handle sections [section]
        if line[0] == b'[':
            section_name = line + 1
            # Find closing bracket
            closing_bracket = strchr(section_name, b']')
            if closing_bracket != NULL:
                closing_bracket[0] = b'\0'
                
                # Handle nested sections [section.subsection]
                parent_dict = root
                section_part = section_name
                while True:
                    dot_pos = strchr(section_part, b'.')
                    if dot_pos != NULL:
                        dot_pos[0] = b'\0'
                        # Get or create parent section
                        if PyDict_Contains(parent_dict, PyUnicode_FromString(section_part)):
                            parent_dict = parent_dict[PyUnicode_FromString(section_part)]
                        else:
                            temp_dict = PyDict_New()
                            PyDict_SetItem(parent_dict, PyUnicode_FromString(section_part), temp_dict)
                            parent_dict = temp_dict
                        section_part = dot_pos + 1
                    else:
                        # Create final section
                        section_dict = PyDict_New()
                        PyDict_SetItem(parent_dict, PyUnicode_FromString(section_part), section_dict)
                        current_section = section_dict
                        break
            continue
        
        # Find key-value pairs
        equal_pos = strchr(line, b'=')
        if equal_pos != NULL:
            # Split into key and value
            equal_pos[0] = b'\0'
            key = line
            value = equal_pos + 1
            
            # Trim whitespace from key
            while key[0] == b' ':
                key += 1
            key_len = strlen(key)
            while key_len > 0 and key[key_len-1] == b' ':
                key[key_len-1] = b'\0'
                key_len -= 1
            
            # Remove trailing newline from value
            value_len = strlen(value)
            if value_len > 0 and value[value_len-1] == b'\n':
                value[value_len-1] = b'\0'
            
            # Parse and store
            PyDict_SetItem(
                current_section,
                PyUnicode_FromString(key),
                parse_value(value)
            )
    
    return root

def read_toml(str file_path):
    """
    Public function to read a TOML file into a dictionary
    """
    cdef:
        FILE* cfile
        dict result
    
    cfile = fopen(file_path.encode('utf-8'), "r")
    if cfile == NULL:
        raise FileNotFoundError(f"Could not open file: {file_path}")
    
    try:
        result = parse_toml_file(cfile)
    finally:
        fclose(cfile)
    
    return result

cdef int write_value(FILE* cfile, object value, int indent_level) except -1:
    """Write a single TOML value with proper formatting"""
    cdef:
        bytes bytes_val
        const char* c_str
        int i
        object item
    
    if value is None:
        return fprintf(cfile, b"null")
    elif isinstance(value, bool):
        return fprintf(cfile, b"%s", b"true" if value else b"false")
    elif isinstance(value, (int, float)):
        bytes_val = PyObject_Str(value).encode('utf-8')
        c_str = bytes_val
        return fprintf(cfile, b"%s", c_str)
    elif PyUnicode_Check(value):
        bytes_val = PyUnicode_AsUTF8String(value)
        c_str = bytes_val
        return fprintf(cfile, b"\"%s\"", c_str)
    elif PyList_Check(value):
        fprintf(cfile, b"[")
        for i in range(PyList_Size(value)):
            if i > 0:
                fprintf(cfile, b", ")
            item = <object>PyList_GetItem(value, i)
            if PyList_Check(item):
                # Handle nested array
                write_value(cfile, item, indent_level)
            else:
                write_value(cfile, item, indent_level)
        return fprintf(cfile, b"]")
    else:
        bytes_val = PyObject_Str(value).encode('utf-8')
        c_str = bytes_val
        return fprintf(cfile, b"\"%s\"", c_str)

cdef int write_section(FILE* cfile, dict data, int indent_level, bytes section_name) except -1:
    """Write a TOML section with proper nesting"""
    cdef:
        PyObject* key_obj = NULL
        PyObject* value_obj = NULL
        Py_ssize_t pos = 0
        bytes bytes_key
        const char* c_key
        dict sub_dict
        bytes full_section_name
    
    # Write section header if not root
    if section_name is not None and indent_level > 0:
        fprintf(cfile, b"\n")
        fprintf(cfile, b"%s", b"    " * (indent_level - 1))
        fprintf(cfile, b"[%s]\n", <char*>section_name)
    
    # Write key-value pairs
    while PyDict_Next(data, &pos, &key_obj, &value_obj):
        key = <object>key_obj
        value = <object>value_obj
        
        # Skip None values
        if value is None:
            continue
            
        bytes_key = key.encode('utf-8') if PyUnicode_Check(key) else PyObject_Str(key).encode('utf-8')
        c_key = bytes_key
        
        # Handle nested dictionaries (sub-sections)
        if isinstance(value, dict):
            if section_name is None:
                full_section_name = bytes_key
            else:
                full_section_name = section_name + b"." + bytes_key
            
            if indent_level < MAX_NESTING:
                write_section(cfile, value, indent_level + 1, full_section_name)
        else:
            # Write regular key-value pair
            fprintf(cfile, b"%s", b"    " * indent_level)
            fprintf(cfile, b"%s = ", c_key)
            write_value(cfile, value, indent_level)
            fprintf(cfile, b"\n")
    
    return 0

def write_toml(str file_path, dict data):
    """Public function to write a dictionary to a TOML file"""
    cdef:
        FILE* cfile
        bytes bytes_path = file_path.encode('utf-8')
        const char* c_path = bytes_path
    
    cfile = fopen(c_path, "wb")
    if cfile == NULL:
        raise IOError(f"Could not open file for writing: {file_path}")
    
    try:
        write_section(cfile, data, 0, None)
    finally:
        fclose(cfile)