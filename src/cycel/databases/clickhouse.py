"""
ClickHouse client helpers and small schema/query builders.

Requires the optional ``databases`` extra (``clickhouse-driver``). The helpers
here focus on connection setup and composing common SQL snippets; they do not
execute queries themselves except inside :func:`create_sync_client` when
``set_async_insert`` is enabled.
"""

from typing import Final

from clickhouse_driver import Client

############################################################
# Queries
############################################################
SHOW_DATABASES_QUERY: Final[str] = "SHOW DATABASES"
SET_ASYNC_INSERT_QUERY: Final[str] = "SET async_insert=1, wait_for_async_insert=0"
DISK_USAGE_QUERY: Final[str] = (
    "SELECT total_space, free_space FROM system.disks WHERE name = 'default'"
)

EXCLUDE_DATABASES: Final[set[str]] = {
    "default",
    "system",
    "information_schema",
    "information",
}


############################################################
# Parameters
############################################################
class ClickHouseParameters:
    """
    Native-protocol connection settings for :class:`clickhouse_driver.Client`.

    Attributes:
        host: Server hostname or IP.
        port: Native TCP port (often 9000).
        user: Database user name.
        password: Database password.

    Example:
        >>> parameters = ClickHouseParameters(
        ...     host="localhost", port=9000, user="default", password="secret"
        ... )
        >>> parameters.host
        'localhost'
    """

    __slots__ = ("host", "port", "user", "password")

    def __init__(self, host: str, port: int, user: str, password: str):
        self.host = host
        self.port = port
        self.user = user
        self.password = password


############################################################
# Schemas
############################################################
class ClickHouseDatabaseSchema:
    """Holds a database name for use in higher-level DDL helpers (lightweight handle)."""

    def __init__(self, database: str) -> None:
        self._database = database


class ClickHouseTableSchema:
    """
    Describe a table's database, name, and column list for INSERT helpers.

    Attributes are exposed read-only via properties. Methods such as
    :meth:`insert_into` return SQL text and parameters for the driver; they do
    not execute statements.

    Example:
        >>> schema = ClickHouseTableSchema(
        ...     database="default", table_name="events", columns=["id", "ts"]
        ... )
        >>> schema.table_name
        'events'
    """

    def __init__(self, database: str, table_name: str, columns: list[str]):
        self._database = database
        self._table_name = table_name
        self._columns = columns
        self._columns_str = ", ".join(columns)

    ############################################################
    # Properties
    ############################################################
    @property
    def database(self) -> str:
        return self._database

    @property
    def table_name(self) -> str:
        return self._table_name

    @property
    def columns(self) -> list[str]:
        return self._columns

    ############################################################
    # Queries
    ############################################################
    def exists(self) -> str:
        """
        Build the ``EXISTS TABLE`` SQL fragment for this table.

        Returns:
            SQL string suitable for ``client.execute(...)``; not a boolean result.
        """
        return f"EXISTS TABLE {self._database}.{self._table_name}"

    def set_async_insert(self) -> str:
        """
        Generate a SQL SET statement for enabling asynchronous inserts and disabling waiting
        for asynchronous insert completion in ClickHouse.

        Returns:
            str: The SQL query string to enable async_insert and disable wait_for_async_insert.
        """
        return SET_ASYNC_INSERT_QUERY

    def insert_into(self, values: list[tuple]) -> tuple[str, list[tuple]]:
        """
        Generate an INSERT INTO SQL statement for ClickHouse, given columns and values.

        Returns:
            tuple[str, list[tuple]]: The SQL query string and the associated parameter values.
        """
        query = f"INSERT INTO {self._database}.{self._table_name} ({self._columns_str}) VALUES"
        return query, values

    def insert_columns_into(
        self, values: list[tuple], columns: list[str]
    ) -> tuple[str, list[tuple]]:
        """
        Generate an INSERT INTO SQL statement for ClickHouse with specific columns.

        Args:
            values: List of tuples containing the values to insert.
            columns: List of column names to insert into.

        Returns:
            tuple[str, list[tuple]]: The SQL query string and the associated parameter values.
        """
        columns_str = ", ".join(columns)
        query = (
            f"INSERT INTO {self._database}.{self._table_name} ({columns_str}) VALUES"
        )
        return query, values


############################################################
# Client
############################################################


def create_sync_client(
    ch_parameters: ClickHouseParameters, set_async_insert: bool = False
) -> Client:
    """
    Create a synchronous ClickHouse client
    Args:
        - ch_parameters: ClickHouseParameters
        - set_async_insert: bool

    Returns:
        - Client

    Example:
    >>> client = create_sync_client(ClickHouseParameters(host="localhost", port=9000, user="default", password="password"))
    >>> client.execute("SELECT 1")
    [1]
    """
    client = Client(
        host=ch_parameters.host,
        port=ch_parameters.port,
        user=ch_parameters.user,
        password=ch_parameters.password,
    )
    if set_async_insert:
        client.execute(SET_ASYNC_INSERT_QUERY)
    return client
