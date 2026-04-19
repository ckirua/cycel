from typing import Any, Dict

def read_toml(file_path: str) -> Dict[str, Any]:
    """
    Read a TOML file into a dictionary.

    Args:
        file_path: Path to the TOML file to read

    Returns:
        Dictionary containing the parsed TOML data

    Raises:
        FileNotFoundError: If the file cannot be opened
    """
    ...

def write_toml(file_path: str, data: Dict[str, Any]) -> None:
    """
    Write a dictionary to a TOML file.

    Args:
        file_path: Path where to write the TOML file
        data: Dictionary containing the data to write

    Raises:
        IOError: If the file cannot be opened for writing
    """
    ...
