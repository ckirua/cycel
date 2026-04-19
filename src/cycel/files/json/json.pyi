from typing import Any, Dict

def read_json(file_path: str) -> Dict[str, Any]:
    """
    Read a JSON file into a dictionary.

    Args:
        file_path: Path to the JSON file to read

    Returns:
        Dictionary containing the parsed JSON data

    Raises:
        FileNotFoundError: If the file cannot be opened
    """
    ...

def write_json(file_path: str, data: Dict[str, Any]) -> None:
    """
    Write a dictionary to a JSON file.

    Args:
        file_path: Path where to write the JSON file
        data: Dictionary containing the data to write
    """
    ...
