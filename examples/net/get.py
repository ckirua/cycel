from cycel import evlib
from cycel.net import HTTPClient, HTTPRequest, HTTPResponse


async def main() -> None:
    async with HTTPClient() as client:
        http_request = HTTPRequest(
            url="https://api.github.com",
            method="GET",
            headers={
                "Accept": "application/json",
            },
        )
        http_response: HTTPResponse = await client.request(http_request)
        print(http_response.content)


if __name__ == "__main__":
    evlib.run(main())
