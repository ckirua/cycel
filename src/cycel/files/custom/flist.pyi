from typing import Iterator, List, Optional, Union, overload

class BaseListFileReader:
    buffer: list
    file_path: str
    strip_lines: bool
    skip_empty_lines: bool
    encoding: str
    comment_prefix: Optional[str]
    max_line_length: int
    _is_read: bool

    def __init__(
        self,
        file_path: str,
        strip_lines: bool = True,
        skip_empty_lines: bool = True,
        encoding: str = "utf-8",
        comment_prefix: Optional[str] = None,
        max_line_length: int = 8192,
    ) -> None: ...
    def clear(self) -> None: ...
    def __len__(self) -> int: ...
    def __getitem__(self, index) -> Union[str, List[str]]: ...
    def __iter__(self) -> Iterator[str]: ...
    def __bool__(self) -> bool: ...
    def __repr__(self) -> str: ...

class ListFileReader(BaseListFileReader):
    def read(self, force_reload: bool = False) -> list: ...

class ListMMAPFileReader(BaseListFileReader):
    def read(self, force_reload: bool = False) -> list: ...
