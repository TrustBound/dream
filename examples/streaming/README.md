# Streaming Example

HTTP client with both streaming and non-streaming requests.

## What This Demonstrates

- **HTTP client builder pattern** - Same pattern used throughout Dream
- **Non-streaming requests** - Fetch full response body
- **Streaming requests** - Process chunks as they arrive
- **HTTPS support** - Secure connections to external APIs
- **External API calls** - Making requests to httpbin.org

## Running the Example

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/streaming
make run
```

Server starts on `http://localhost:3003`

## Endpoints

- `GET /` - Info page explaining the example
- `GET /fetch` - Non-streaming HTTP request to httpbin.org
- `GET /stream` - Streaming HTTP request to httpbin.org

## Example Usage

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming/test/integration/readme.sh#L3-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Info page
curl http://localhost:3003/

# Non-streaming request (waits for full response)
curl http://localhost:3003/fetch

# Streaming request (processes chunks as they arrive)
curl http://localhost:3003/stream
```

## Code Structure

```text illustration
examples/streaming/
├── gleam.toml          # Project config
├── Makefile            # Build and run commands
└── src/
    ├── main.gleam     # Application entry point
    ├── router.gleam   # Route definitions
    ├── services.gleam  # Empty services
    └── controllers/
        └── stream_controller.gleam  # HTTP client usage
```

## Key Concepts

- **Non-Streaming** - `fetch.request()` returns full response body
- **Streaming** - `stream.request()` yields chunks as they arrive
- **Builder Pattern** - Chain method calls to configure request
- **HTTPS** - Use `client.scheme(http.Https)` for secure connections

## When to Use Each

- **Non-streaming** (`fetch`) - Small responses, need full body at once
- **Streaming** (`stream`) - Large responses, want to process incrementally

This example demonstrates Dream's HTTP client capabilities for both streaming and non-streaming requests.

