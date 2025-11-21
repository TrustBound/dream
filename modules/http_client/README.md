# dream_http_client

**Type-safe HTTP client for Gleam with streaming support.**

A standalone HTTP/HTTPS client built on Erlang's battle-tested `httpc`. Supports both streaming and non-streaming requests. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ Streaming and non-streaming modes
- ✅ HTTPS support (TLS/SSL)
- ✅ Builder pattern for request configuration
- ✅ Type-safe with `Result` types
- ✅ Battle-tested Erlang `httpc` under the hood
- ✅ Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_http_client
```

## Quick Start

### Non-Streaming Requests

Perfect for JSON APIs and small responses:

```gleam
import dream_http_client/client
import dream_http_client/fetch
import gleam/http

let result = client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users/123")
  |> client.add_header("Authorization", "Bearer " <> token)
  |> fetch.request()

case result {
  Ok(body) -> decode_json(body)
  Error(msg) -> handle_error(msg)
}
```

### Streaming Requests

Perfect for large files, AI responses, or real-time data:

```gleam
import dream_http_client/client
import dream_http_client/stream
import gleam/http
import gleam/yielder

client.new
  |> client.host("cdn.example.com")
  |> client.path("/large-file.zip")
  |> stream.stream_request()
  |> yielder.each(fn(chunk) {
    // Process each chunk as it arrives
    save_chunk(chunk)
  })
```

## Usage

### Building Requests

Use the builder pattern to configure requests:

```gleam
import dream_http_client/client
import gleam/http

let request = client.new
  |> client.method(http.Post)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.port(443)
  |> client.path("/api/users")
  |> client.query("page=1&limit=10")
  |> client.add_header("Content-Type", "application/json")
  |> client.add_header("Authorization", "Bearer " <> token)
  |> client.body(json_body)
```

### Non-Streaming (Fetch)

Get the complete response body at once:

```gleam
import dream_http_client/fetch

case fetch.request(client_request) {
  Ok(body) -> {
    // Process complete response
    case json.decode(body, user_decoder) {
      Ok(user) -> Ok(user)
      Error(_) -> Error("Invalid JSON")
    }
  }
  Error(msg) -> Error("Request failed: " <> msg)
}
```

### Streaming

Process chunks as they arrive:

```gleam
import dream_http_client/stream
import gleam/yielder
import gleam/bytes_tree

// Process chunks incrementally
stream.stream_request(client_request)
  |> yielder.each(fn(chunk) {
    let text = bytes_tree.to_string(chunk)
    io.println("Received: " <> text)
  })

// Or collect all chunks
let chunks = stream.stream_request(client_request)
  |> yielder.to_list()
```

### POST Requests with JSON

```gleam
import dream_http_client/client
import dream_http_client/fetch
import gleam/http
import gleam/json

let user_json = json.object([
  #("name", json.string("Alice")),
  #("email", json.string("alice@example.com")),
])

let request = client.new
  |> client.method(http.Post)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.add_header("Content-Type", "application/json")
  |> client.body(json.to_string(user_json))
  |> fetch.request()
```

## API Reference

### Client Configuration

- `client.new` - Default request configuration
- `client.method(req, method)` - Set HTTP method
- `client.scheme(req, scheme)` - Set protocol (HTTP/HTTPS)
- `client.host(req, host)` - Set hostname
- `client.port(req, port)` - Set port number
- `client.path(req, path)` - Set request path
- `client.query(req, query)` - Set query string
- `client.body(req, body)` - Set request body
- `client.add_header(req, name, value)` - Add header
- `client.headers(req, headers)` - Replace all headers

### Request Execution

- `fetch.request(req) -> Result(String, String)` - Non-streaming request
- `stream.stream_request(req) -> Yielder(BytesTree)` - Streaming request

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow
- **No anonymous functions** - Named functions for clarity
- **Builder pattern** - Consistent, composable APIs
- **Type safety** - `Result` types force error handling
- **Quality testing** - Comprehensive test coverage

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT License - see LICENSE file for details.
