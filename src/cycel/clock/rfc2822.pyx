"""
Parse RFC 2822 (email/HTTP style) date ``bytes`` into timestamps or datetimes.

Optimized for ASCII headers; raises :exc:`ValueError` on malformed input.
"""

import datetime

import cython

from libc.stdio cimport sscanf
from libc.string cimport strchr
from libc.time cimport time_t, tm


@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
cdef inline int get_month_num(const char* month) except -1 nogil:
    if month[0] == ord('J'):
        if month[1] == ord('a') and month[2] == ord('n'):
            return 1
        elif month[1] == ord('u'):
            if month[2] == ord('n'):
                return 6
            elif month[2] == ord('l'):
                return 7
    elif month[0] == ord('F') and month[2] == ord('b'):
        return 2
    elif month[0] == ord('M'):
        if month[1] == ord('a'):
            if month[2] == ord('r'):
                return 3
            elif month[2] == ord('y'):
                return 5
    elif month[0] == ord('A'):
        if month[1] == ord('p') and month[2] == ord('r'):
            return 4
        elif month[1] == ord('u') and month[2] == ord('g'):
            return 8
    elif month[0] == ord('S') and month[1] == ord('e') and month[2] == ord('p'):
        return 9
    elif month[0] == ord('O') and month[1] == ord('c') and month[2] == ord('t'):
        return 10
    elif month[0] == ord('N') and month[1] == ord('o') and month[2] == ord('v'):
        return 11
    elif month[0] == ord('D') and month[1] == ord('e') and month[2] == ord('c'):
        return 12
    return -1


@cython.boundscheck(False)
@cython.wraparound(False)
def parse_rfc2822_bytes_to_timestamp(bytes datestr):
    """
    Fast RFC2822 date parser returning Unix timestamp (UTC).
    Handles dates with GMT (treated as UTC) or without timezone offset.
    """
    cdef char* ptr = <char*>datestr
    cdef char* comma_pos
    cdef int day, year, hour, minute, sec, month_num
    cdef char month_str[4]
    cdef tm time_struct
    cdef time_t timestamp

    # Skip day name if present
    comma_pos = strchr(ptr, ord(','))
    if comma_pos != NULL:
        ptr = comma_pos + 2  # skip ", "

    # Parse the date components (try with GMT first, then without)
    cdef int parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d GMT",
                             &day, month_str, &year, &hour, &minute, &sec)
    
    if parsed != 6:
        # Try without GMT
        parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d",
                        &day, month_str, &year, &hour, &minute, &sec)
    


    if parsed != 6:
        raise ValueError("Invalid date format")

    month_str[3] = 0  # Null-terminate for safety
    month_num = get_month_num(month_str)
    if month_num == -1:
        raise ValueError("Invalid month")

    # Fill tm structure
    time_struct.tm_year = year - 1900
    time_struct.tm_mon = month_num - 1
    time_struct.tm_mday = day
    time_struct.tm_hour = hour
    time_struct.tm_min = minute
    time_struct.tm_sec = sec
    time_struct.tm_wday = 0
    time_struct.tm_yday = 0
    time_struct.tm_isdst = 0

    timestamp = timegm(&time_struct)
    if timestamp == -1:
        raise ValueError("Invalid date")

    # Use Python datetime for more reliable timezone handling
    dt = datetime.datetime(year, month_num, day, hour, minute, sec, tzinfo=datetime.timezone.utc)
    return dt.timestamp()

@cython.boundscheck(False)
@cython.wraparound(False)
def parse_rfc2822_bytes_to_timestamp_with_tz(bytes datestr):
    """
    Parse a date string that includes a numeric timezone offset to Unix time.

    Accepts ``±HHMM`` or a compact ``±HHMM`` four-digit style; interprets the
    local wall time in that offset and returns seconds since the Unix epoch in
    UTC (as :class:`float`).

    Args:
        datestr: ASCII/bytes header value, e.g. ``b'Wed, 02 Jun 2021 14:07:00 +0200'``.

    Returns:
        UTC timestamp suitable for :class:`datetime.datetime.utcfromtimestamp`
        style use (but prefer aware APIs).

    Raises:
        ValueError: If the buffer does not match an expected pattern.
    """
    cdef char* ptr = <char*>datestr
    cdef char* comma_pos
    cdef int day, year, hour, minute, sec, month_num
    cdef char month_str[4]
    cdef char sign = 0
    cdef int tz_hour = 0, tz_minute = 0
    cdef int tz_offset = 0
    cdef int offset_seconds = 0
    cdef tm time_struct
    cdef time_t timestamp

    # Skip day name if present
    comma_pos = strchr(ptr, ord(','))
    if comma_pos != NULL:
        ptr = comma_pos + 2  # skip ", "

    # Parse the date components and timezone
    cdef int parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d %c%2d%2d",
                             &day, month_str, &year, &hour, &minute, &sec, &sign, &tz_hour, &tz_minute)
    
    # If the first format fails, try parsing the timezone as a single 4-digit offset
    if parsed != 9:
        parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d %d",
                        &day, month_str, &year, &hour, &minute, &sec, &tz_offset)
        if parsed == 7:
            # Extract sign and components from the 4-digit offset
            if tz_offset >= 0:
                sign = ord('+')
                tz_hour = tz_offset // 100
                tz_minute = tz_offset % 100
            else:
                sign = ord('-')
                tz_hour = (-tz_offset) // 100
                tz_minute = (-tz_offset) % 100
            parsed = 9  # Mark as successfully parsed

    if parsed != 9:
        raise ValueError("Invalid date format or missing timezone")

    month_str[3] = 0  # Null-terminate for safety
    month_num = get_month_num(month_str)
    if month_num == -1:
        raise ValueError("Invalid month")

    # Fill tm structure as UTC (the input time is in local time of the offset)
    time_struct.tm_year = year - 1900
    time_struct.tm_mon = month_num - 1
    time_struct.tm_mday = day
    time_struct.tm_hour = hour
    time_struct.tm_min = minute
    time_struct.tm_sec = sec
    time_struct.tm_wday = 0
    time_struct.tm_yday = 0
    time_struct.tm_isdst = 0

    # The parsed time is in the local time of the offset, so we must subtract the offset to get UTC
    timestamp = timegm(&time_struct)
    if timestamp == -1:
        raise ValueError("Invalid date")

    offset_seconds = tz_hour * 3600 + tz_minute * 60
    if sign == ord('+'):
        # Time is ahead of UTC, so subtract offset to get UTC
        timestamp -= offset_seconds
    elif sign == ord('-'):
        # Time is behind UTC, so add offset to get UTC
        timestamp += offset_seconds
    else:
        raise ValueError("Invalid timezone sign")

    # Use Python datetime for more reliable timezone handling
    dt = datetime.datetime(year, month_num, day, hour, minute, sec, tzinfo=datetime.timezone.utc)
    # Apply the offset to get the correct UTC time
    if sign == ord('+'):
        dt = dt - datetime.timedelta(hours=tz_hour, minutes=tz_minute)
    elif sign == ord('-'):
        dt = dt + datetime.timedelta(hours=tz_hour, minutes=tz_minute)
    
    return dt.timestamp()

@cython.boundscheck(False)
@cython.wraparound(False)
def parse_rfc2822_bytes_to_datetime(bytes datestr):
    """
    Parse RFC2822 bytes directly to a Python datetime.datetime object (UTC).
    Handles both with and without timezone offset.
    """
    cdef char* ptr = <char*>datestr
    cdef char* comma_pos
    cdef int day, year, hour, minute, sec, month_num
    cdef char month_str[4]
    cdef char sign = 0
    cdef int tz_hour = 0
    cdef int tz_minute = 0
    cdef int tz_offset = 0
    cdef int parsed
    import datetime

    # Skip day name if present
    comma_pos = strchr(ptr, ord(','))
    if comma_pos != NULL:
        ptr = comma_pos + 2  # skip ", "

    # Try to parse with timezone first
    parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d %c%2d%2d",
                    &day, month_str, &year, &hour, &minute, &sec, &sign, &tz_hour, &tz_minute)
    
    # If the first format fails, try parsing the timezone as a single 4-digit offset
    if parsed != 9:
        parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d %d",
                        &day, month_str, &year, &hour, &minute, &sec, &tz_offset)
        if parsed == 7:
            # Extract sign and components from the 4-digit offset
            if tz_offset >= 0:
                sign = ord('+')
                tz_hour = tz_offset // 100
                tz_minute = tz_offset % 100
            else:
                sign = ord('-')
                tz_hour = (-tz_offset) // 100
                tz_minute = (-tz_offset) % 100
            parsed = 9  # Mark as successfully parsed
    
    if parsed == 9:
        month_str[3] = 0
        month_num = get_month_num(month_str)
        if month_num == -1:
            raise ValueError("Invalid month")
        dt = datetime.datetime(year, month_num, day, hour, minute, sec)
        offset = datetime.timedelta(hours=tz_hour, minutes=tz_minute)
        if sign == ord('+'):
            dt_utc = dt - offset
        elif sign == ord('-'):
            dt_utc = dt + offset
        else:
            raise ValueError("Invalid timezone sign")
        return dt_utc.replace(tzinfo=datetime.timezone.utc)

    # Fallback: try without timezone (including GMT)
    parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d GMT",
                    &day, month_str, &year, &hour, &minute, &sec)
    if parsed == 6:
        month_str[3] = 0
        month_num = get_month_num(month_str)
        if month_num == -1:
            raise ValueError("Invalid month")
        return datetime.datetime(year, month_num, day, hour, minute, sec, tzinfo=datetime.timezone.utc)
    
    # Try without GMT
    parsed = sscanf(ptr, b"%d %3s %d %d:%d:%d",
                    &day, month_str, &year, &hour, &minute, &sec)
    if parsed == 6:
        month_str[3] = 0
        month_num = get_month_num(month_str)
        if month_num == -1:
            raise ValueError("Invalid month")
        return datetime.datetime(year, month_num, day, hour, minute, sec, tzinfo=datetime.timezone.utc)

    raise ValueError("Invalid date format")
