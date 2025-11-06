# Streaming Example

HTTP client with both streaming and non-streaming requests.

## What This Demonstrates

- **HTTP client builder pattern** - Same pattern used throughout Dream
- **Non-streaming requests** - Fetch full response body
- **Streaming requests** - Process chunks as they arrive
- **HTTPS support** - Secure connections to external APIs
- **External API calls** - Making requests to httpbin.org

## Running the Example

```bash
cd examples/streaming
make run
```

Server starts on `http://localhost:3000`

## Endpoints

- `GET /` - Info page explaining the example
- `GET /fetch` - Non-streaming HTTP request to httpbin.org
- `GET /stream` - Streaming HTTP request to httpbin.org

## Example Usage

```bash
# Info page
curl http://localhost:3000/

# Non-streaming request (waits for full response)
curl http://localhost:3000/fetch

# Streaming request (processes chunks as they arrive)
curl http://localhost:3000/stream
```

## Code Structure

```
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

