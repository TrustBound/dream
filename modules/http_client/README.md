# dream_http_client

HTTP client for Dream applications.

Provides streaming and non-streaming HTTP/HTTPS client built on Erlang's httpc.

## Features

- Streaming and non-streaming modes
- HTTPS support
- Builder pattern for requests
- Battle-tested Erlang httpc under the hood

## Usage

```gleam
import dream_http_client/client
import gleam_http as http

// Non-streaming request
let response = client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.fetch()

// Streaming request
let stream = client.new()
  |> client.method(http.Get)
  |> client.host("api.example.com")
  |> client.path("/stream")
  |> client.stream()
```

