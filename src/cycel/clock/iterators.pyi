import datetime
from typing import Iterator

class StrfTimeIterator:
    def __init__(
        self,
        start: datetime.datetime,
        end: datetime.datetime,
        step: datetime.timedelta,
        format: str = "%Y-%m-%d %H:%M:%S",
    ) -> None: ...
    def __iter__(self) -> Iterator[str]: ...
    def __next__(self) -> str: ...

class DateTimeIterator:
    def __init__(
        self, start: datetime.datetime, end: datetime.datetime, step: datetime.timedelta
    ) -> None: ...
    def __iter__(self) -> Iterator[datetime.datetime]: ...
    def __next__(self) -> datetime.datetime: ...
