"""Use cycel.arrow.pa_file_exists with a PyArrow FileSystem (local paths)."""

from __future__ import annotations

import tempfile
from pathlib import Path

import pyarrow.fs as pafs

from cycel.arrow import pa_file_exists


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        present = root / "present.txt"
        present.write_text("hello", encoding="utf-8")
        absent = root / "absent.txt"

        fs = pafs.LocalFileSystem()

        print(f"{present.name} exists: {pa_file_exists(fs, str(present))}")
        print(f"{absent.name} exists: {pa_file_exists(fs, str(absent))}")


if __name__ == "__main__":
    main()
