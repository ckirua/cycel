import os
from pathlib import Path

from clickhouse_driver import Client
from dotenv import load_dotenv
from cycel import evlib
from cycel.databases.clickhouse import (
    DISK_USAGE_QUERY,
    EXCLUDE_DATABASES,
    SHOW_DATABASES_QUERY,
)


_TIME_COLUMN = "event_time"


def _format_size(size_bytes: int) -> str:
    """Format bytes to human readable size."""
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} PB"


_NATIVE_PORT_HINT = (
    "This script uses clickhouse_driver (native TCP, default port 9000). "
    "Connection refused usually means port 9000 is closed on the firewall or "
    "ClickHouse is not listening on the public interface. "
    "Options: open/forward TCP 9000, or SSH tunnel (e.g. "
    "`ssh -L 9000:127.0.0.1:9000 user@host` and set CLICKHOUSE_HOST=127.0.0.1). "
    "HTTP-only access on 8123 needs a different client, not clickhouse_driver."
)


async def main():
    load_dotenv(Path.home() / ".env")

    host = os.getenv("CLICKHOUSE_HOST")
    port = int(os.getenv("CLICKHOUSE_PORT", "9000"))
    user = os.getenv("CLICKHOUSE_USER")
    password = os.getenv("CLICKHOUSE_PASSWORD")

    try:
        client = Client(host=host, port=port, user=user, password=password)

        # Disk usage summary
        total_space, free_space = client.execute(DISK_USAGE_QUERY)[0]
        used_space = total_space - free_space
        pct_used = (used_space / total_space) * 100 if total_space > 0 else 0
        print(
            f"Disk: {_format_size(used_space)} / {_format_size(total_space)} ({pct_used:.1f}% used)"
        )

        all_databases = client.execute(SHOW_DATABASES_QUERY)
        user_databases = [
            db[0] for db in all_databases if db[0].lower() not in EXCLUDE_DATABASES
        ]
        for db in user_databases:
            tables_query = f"SHOW TABLES FROM `{db}`"
            tables = [t[0] for t in client.execute(tables_query)]
            print(f"\nDatabase: {db}")
            for table in tables:
                rows = client.execute(f"SELECT count(*) FROM `{db}`.`{table}`")[0][0]
                size_query = f"""
                    SELECT sum(bytes_on_disk) FROM system.parts
                    WHERE database = '{db}' AND table = '{table}' AND active
                """
                size_bytes = client.execute(size_query)[0][0] or 0
                size_str = _format_size(size_bytes)
                if rows > 0:
                    date_query = f"SELECT min({_TIME_COLUMN}), max({_TIME_COLUMN}) FROM `{db}`.`{table}`"
                    min_date, max_date = client.execute(date_query)[0]
                    print(
                        f"  {table}: {rows:,} rows | {size_str} | {min_date} → {max_date}"
                    )
                else:
                    print(f"  {table}: empty | {size_str}")
    except Exception as e:
        print(f"Error connecting to ClickHouse or fetching databases: {e}")
        err_name = type(e).__name__
        msg = str(e).lower()
        if err_name == "ConnectionRefusedError" or "connection refused" in msg or "code: 210" in msg:
            print(_NATIVE_PORT_HINT)


if __name__ == "__main__":
    evlib.run(main())
