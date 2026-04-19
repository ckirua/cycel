from typing import List

class ZipFile:
    filename: str
    data: list[int]  # actually bytes, but exposed as list of ints for speed

    def get_data_as_bytes(self) -> bytes: ...

def extract_zip(data: bytes) -> List[ZipFile]: ...
