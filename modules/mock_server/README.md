# Dream Mock Server

A general-purpose HTTP mock server developed by Dream that provides both streaming and non-streaming endpoints for testing HTTP clients.

**Current module version:** `1.1.1`

## Overview

This module provides a comprehensive set of endpoints for testing HTTP clients:

- **Non-streaming endpoints** - Standard REST-like endpoints (GET, POST, PUT, DELETE)
- **Streaming endpoints** - Various streaming behaviors for testing chunked responses

All endpoints are deterministic and designed for testing, making them ideal for:

- **Testing** - Use as a test fixture for HTTP client integration tests
- **Demo** - Showcase Dream's HTTP capabilities with predictable behavior
- **Learning** - Study different HTTP patterns and error handling

## Running

### Standalone Mode

Start the server on port 3004:

```bash
make run
```

Then access endpoints at `http://localhost:3004/`

### Programmatic Mode

Use in tests or other applications:

#### Run a test body against the mock server <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/programmatic_mode.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_mock_server/server
import gleam/int
import gleam/otp/actor

pub fn with_mock_server(
  port: Int,
  test_body: fn(String) -> outcome,
) -> Result(outcome, actor.StartError) {
  case server.start(port) {
    Ok(handle) -> {
      // Make HTTP requests to the base URL, http://localhost:<port>
      let outcome = test_body("http://localhost:" <> int.to_string(port))
      server.stop(handle)
      Ok(outcome)
    }
    Error(start_error) -> Error(start_error)
  }
}
```

### Config mode

For proxy tests or any test that needs a **deterministic upstream** with specific status and body per path, start the server with a config list. The mock has no built-in provider logic (no OpenAI, Google, AWS, etc.); the caller supplies all path → (status, body) mappings. First matching route in the list wins.

#### Start with one prefix route <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/config_mode_prefix.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/servers/mist/server as dream_server
import dream_mock_server/config.{type MockRoute, MockRoute, Prefix}
import dream_mock_server/server
import gleam/option.{None}
import gleam/otp/actor

/// One route: path /v1/chat/completions (prefix match), any method, 200 + JSON body
pub fn chat_completion_routes() -> List(MockRoute) {
  [
    MockRoute(
      path: "/v1/chat/completions",
      path_match: Prefix,
      method: None,
      status: 200,
      body: "{\"choices\":[{\"message\":{\"content\":\"\"}}]}",
    ),
  ]
}

pub fn start_chat_mock(
  port: Int,
) -> Result(dream_server.ServerHandle, actor.StartError) {
  // Point your proxy or client at http://localhost:<port>,
  // then call server.stop(handle).
  server.start_with_config(port, chat_completion_routes())
}
```

#### How matching works

- Matching is **first route wins** in list order.
- `Exact` means request path must equal `path`.
- `Prefix` means request path must start with `path`.
- `method: Some(Get)` (or Post/Put/Delete/Patch) restricts by method.
- `method: None` matches any method.
- No match returns `404` with body `"Not found"`.

#### Exact + method-specific example <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/config_mode_method_specific.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{Get, Post}
import dream_mock_server/config.{type MockRoute, Exact, MockRoute}
import gleam/option.{Some}

// GET /resource  -> 200 {"ok":true}
// POST /resource -> 201 {"created":true}
pub fn resource_routes() -> List(MockRoute) {
  [
    MockRoute("/resource", Exact, Some(Get), 200, "{\"ok\":true}"),
    MockRoute("/resource", Exact, Some(Post), 201, "{\"created\":true}"),
  ]
}
```

#### Ordering gotcha (important)

If you mix broad prefixes and specific routes, put specific routes first:

##### Good: specific route first <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/config_mode_ordering.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_mock_server/config.{type MockRoute, Exact, MockRoute, Prefix}
import gleam/option.{None}

// Good: specific before broad prefix
pub fn api_routes() -> List(MockRoute) {
  [
    MockRoute("/api/special", Exact, None, 200, "special"),
    MockRoute("/api", Prefix, None, 200, "general"),
  ]
}
```

- **Path match:** `Exact` (path must equal) or `Prefix` (path must start with).
- **Method:** `Some(Get)` etc. to restrict; `None` for any method.
- **Order:** Put more specific routes before broader prefix routes so they match first.
- **No match:** Returns 404 with body `"Not found"`.

## Non-Streaming Endpoints

### `GET /get`

**Returns JSON with request info**

- Returns: `{"method": "GET", "url": "/get", "headers": []}`
- Status: 200 OK
- Content-Type: `application/json`

**Use for:** Testing GET requests, JSON parsing

### `POST /post`

**Echoes request body as JSON**

- Returns: `{"method": "POST", "url": "/post", "data": "<request body>"}`
- Status: 201 Created
- Content-Type: `application/json`

**Use for:** Testing POST requests, request body handling

### `PUT /put`

**Echoes request body as JSON**

- Returns: `{"method": "PUT", "url": "/put", "data": "<request body>"}`
- Status: 200 OK
- Content-Type: `application/json`

**Use for:** Testing PUT requests

### `DELETE /delete`

**Returns success response**

- Returns: `{"method": "DELETE", "url": "/delete"}`
- Status: 200 OK
- Content-Type: `application/json`

**Use for:** Testing DELETE requests

### `GET /json`

**Returns simple JSON object**

- Returns: `{"message": "Hello, World!", "success": true}`
- Status: 200 OK
- Content-Type: `application/json`

**Use for:** Testing JSON parsing, simple responses

### `GET /text`

**Returns plain text**

- Returns: `"Hello, World!"`
- Status: 200 OK
- Content-Type: `text/plain`

**Use for:** Testing text responses

### `GET /uuid`

**Returns UUID-like string**

- Returns: `{"uuid": "123e4567-e89b-12d3-a456-426614174000"}`
- Status: 200 OK
- Content-Type: `application/json`

**Use for:** Testing small JSON responses

### `GET /`

**Info page** - Lists all available endpoints with descriptions

**Use for:** Documentation, service discovery

## Streaming Endpoints

### `GET /stream/fast`

**10 chunks at 100ms intervals**

- Fast streaming for quick response handling
- Total duration: ~1 second
- Each chunk: `"Chunk N\n"`

**Use for:** Testing fast streaming, basic functionality

### `GET /stream/slow`

**5 chunks at 2s intervals**

- Slow streaming for timeout handling
- Total duration: ~10 seconds
- Each chunk: `"Chunk N\n"`

**Use for:** Testing timeout handling, long-running streams

### `GET /stream/burst`

**7 chunks with variable delays (100-500ms)**

- Deterministic burst pattern for robustness testing
- Delays: `[100, 500, 200, 400, 100, 300, 200]` ms
- Each chunk: `"Burst N\n"`

**Use for:** Testing variable timing patterns, buffering behavior

### `GET /stream/error`

**3 chunks then 500 status**

- Returns HTTP 500 with partial content
- Simulates mid-stream error
- Each chunk: `"Error test chunk N\n"`

**Use for:** Testing error handling mid-stream

### `GET /stream/huge`

**100 chunks with 10ms delays**

- Large response for memory/performance testing
- Total duration: ~1 second
- Each chunk: `"Huge chunk N\n"`

**Use for:** Memory efficiency, performance testing

### `GET /stream/json`

**5 JSON objects at 200ms intervals**

- Structured data streaming
- Each chunk: `{"event":"chunk","number":N,"message":"JSON event N"}\n`
- Content-Type: `application/json`

**Use for:** Testing structured data streaming, JSON handling

### `GET /stream/binary`

**256 binary chunks with byte patterns**

- Non-text streaming
- Each chunk: 4 bytes with repeating pattern
- Content-Type: `application/octet-stream`

**Use for:** Testing binary data streaming

## Integration Tests

Run Cucumber integration tests:

```bash
make test-integration
```

Tests verify:
- All endpoints return correct status codes
- Content format and structure
- Chunk counts and timing
- Error handling
- JSON validity

## Usage Modes

### 1. Standalone Server

Fixed port 3004, runs indefinitely:

```bash
make run
```

### 2. Programmatic Control

Start/stop programmatically for tests. `http_helper` and `port` are small test helpers in this module's `test/snippets/` folder.

#### Start, use and stop the server <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/programmatic_control.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/servers/mist/server as dream_server
import dream_mock_server/server
import gleam/int
import gleam/result
import gleam/string
import snippets/http_helper

pub fn fetch_text(port: Int) -> Result(#(Int, String), String) {
  // Start server
  use handle <- result.try(start_server(port))

  // Use server
  let response =
    http_helper.get("http://localhost:" <> int.to_string(port) <> "/text")

  // Stop server
  server.stop(handle)
  response
}

fn start_server(port: Int) -> Result(dream_server.ServerHandle, String) {
  server.start(port)
  |> result.map_error(string.inspect)
}
```

### 3. Integration Testing

Dream's HTTP client tests use the mock server in this way. This test starts the server on a free port from the operating system:

#### A test against the mock server <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/integration_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_mock_server/server
import gleam/int
import gleeunit/should
import snippets/http_helper
import snippets/port

pub fn fast_stream_sends_ten_chunks_test() {
  let port = port.free_port()
  let mock = server.start(port) |> should.be_ok()

  // Send the request to http://localhost:<port>
  let response =
    http_helper.get(
      "http://localhost:" <> int.to_string(port) <> "/stream/fast",
    )

  server.stop(mock)
  response
  |> should.equal(
    Ok(#(
      200,
      "Chunk 1\nChunk 2\nChunk 3\nChunk 4\nChunk 5\nChunk 6\nChunk 7\nChunk 8\nChunk 9\nChunk 10\n",
    )),
  )
}
```

## Implementation Details

### Streaming Technique

Streaming endpoints use Dream's `response.stream_response()`:

#### Fast stream controller <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/streaming_technique.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/yielder

pub fn stream_fast(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 10)
    |> yielder.map(create_fast_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_fast_chunk(number: Int) -> BitArray {
  process.sleep(100)
  let line = "Chunk " <> int.to_string(number) <> "\n"
  bit_array.from_string(line)
}
```

### Non-Streaming Technique

Non-streaming endpoints use standard `json_response()` and `text_response()`:

#### JSON controller <a href="https://github.com/TrustBound/dream/blob/dream_mock_server-1.1.1/modules/mock_server/test/snippets/non_streaming_technique.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/json

pub fn get(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let body =
    json.object([
      #("method", json.string("GET")),
      #("url", json.string(request.path)),
    ])
    |> json.to_string

  json_response(status.ok, body)
}
```

### Timing Control

Streaming endpoints use `process.sleep()` between chunks for deterministic timing:

- **Fast**: 100ms delays
- **Slow**: 2000ms delays
- **Burst**: Variable 100-500ms delays
- **Huge**: 10ms delays (optimized for throughput)

### Error Simulation

The `/stream/error` endpoint demonstrates mid-stream errors by returning a 500 status with partial content. This tests client error handling during streaming.

## Architecture

```
src/
├── main.gleam                    # Standalone entry point (port 3004)
├── dream_mock_server/
│   ├── server.gleam             # Programmatic start/stop functions
│   ├── router.gleam             # Route definitions
│   ├── controllers/
│   │   ├── api_controller.gleam      # Non-streaming endpoints
│   │   └── stream_controller.gleam   # Streaming endpoints
│   └── views/
│       └── index_view.gleam          # Info page HTML
```

## Dependencies

- **Dream** - Web framework
- **gleam_erlang** - Process control (sleep)
- **gleam_json** - JSON encoding
- **gleam_yielder** - Stream generation

## All Examples Are Tested

The core usage examples in this README are backed by runnable snippet tests
under `test/snippets/` and executed by `test/snippets_test.gleam`.

Run them with:

```bash
cd modules/mock_server
gleam test
```

## See Also

- [Dream Streaming Guide](../../docs/guides/streaming.md)
- [HTTP Client Module](../../modules/http_client/)
- [Streaming Capabilities Example](../streaming_capabilities/)
