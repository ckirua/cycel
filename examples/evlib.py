from cycel import evlib


async def main() -> None:
    print("Hello asyncio!")
    await evlib.sleep(1)
    print("Hello asyncio again!")


if __name__ == "__main__":
    evlib.run(main())
