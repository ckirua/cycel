"""
Time utilities: nanosecond clocks, epoch conversions, ranges, iterators, RFC 2822.

**Clocks** — :func:`clock_monotonic`, :func:`clock_realtime`, and (on POSIX)
``clock_*_raw`` / ``clock_*_coarse`` variants read ``clock_gettime`` and return
integer **nanoseconds** since the relevant origin (monotonic origin or Unix
epoch for realtime).

**Conversions** — bidirectional mapping between UTC :class:`~datetime.datetime`
and integer or float timestamps in ns, µs, ms, or seconds; :func:`change_ts_units`
rescales between those units.

**Ranges / iterators** — materialize or lazily step ``datetime`` sequences with
a :class:`~datetime.timedelta` step.

**RFC 2822** — parse HTTP-style date headers from ``bytes`` into timestamps or
timezone-aware datetimes.
"""

import sys

from .clock import clock_datetime, clock_monotonic, clock_realtime
from .iterators import DateTimeIterator, StrfTimeIterator
from .conversions import (
    change_ts_units,
    datetime_to_ms,
    datetime_to_ns,
    datetime_to_s,
    datetime_to_us,
    ms_to_datetime,
    ns_to_datetime,
    s_to_datetime,
    us_to_datetime,
)
from .ranges import datetime_range, strftime_range
from .rfc2822 import (
    parse_rfc2822_bytes_to_datetime,
    parse_rfc2822_bytes_to_timestamp,
    parse_rfc2822_bytes_to_timestamp_with_tz,
)

__all__: tuple[str, ...] = (
    # Clock
    "clock_datetime",
    "clock_monotonic",
    "clock_realtime",
    # Ranges
    "datetime_range",
    "strftime_range",
    # Iterators
    "DateTimeIterator",
    "StrfTimeIterator",
    # Conversions
    "change_ts_units",
    "datetime_to_ms",
    "datetime_to_ns",
    "datetime_to_s",
    "datetime_to_us",
    "ms_to_datetime",
    "ns_to_datetime",
    "s_to_datetime",
    "us_to_datetime",
    # RFC 2822
    "parse_rfc2822_bytes_to_datetime",
    "parse_rfc2822_bytes_to_timestamp",
    "parse_rfc2822_bytes_to_timestamp_with_tz",
)
if not sys.platform.startswith("win"):
    try:
        from .clock import (
            clock_monotonic_coarse,
            clock_monotonic_raw,
            clock_realtime_coarse,
        )

        __all__ += (
            "clock_monotonic_coarse",
            "clock_monotonic_raw",
            "clock_realtime_coarse",
        )
    except ImportError:
        pass
