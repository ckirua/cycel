from cycel import evlib
from cycel.logging import get_logger, load_dict_config

# Standard dictConfig layout; see logging.config documentation for all keys.
_LOGGING: dict = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "brief": {
            "format": "%(asctime)s %(levelname)-8s [%(name)s] %(message)s",
            "datefmt": "%H:%M:%S",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "brief",
        },
    },
    "root": {
        "level": "DEBUG",
        "handlers": ["console"],
    },
}


async def main() -> None:
    load_dict_config(_LOGGING)
    log = get_logger("example.basic_logger")
    log.debug("debug message")
    log.info("info message")
    log.warning("warning message")
    await evlib.sleep(0)


if __name__ == "__main__":
    evlib.run(main())
