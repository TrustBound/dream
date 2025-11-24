# Dream Mock Server

A general-purpose HTTP mock server developed by Dream that provides both streaming and non-streaming endpoints for testing HTTP clients.

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

```gleam
import dream_mock_server/server

pub fn my_test() {
  let assert Ok(handle) = server.start(3004)
  
  // Make HTTP requests to localhost:3004
  // ... test logic ...
  
  server.stop(handle)
}
```

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

Start/stop programmatically for tests:

```gleam
import dream_mock_server/server

// Start server
let assert Ok(handle) = server.start(3004)

// Use server...

// Stop server
server.stop(handle)
```

### 3. Integration Testing

Used by Dream's HTTP client tests:

```gleam
// In modules/http_client/test/integration_test.gleam
import dream_mock_server/server

pub fn concurrent_streams_test() {
  let assert Ok(mock) = server.start(3004)
  
  // Test HTTP client against localhost:3004
  // ...
  
  server.stop(mock)
}
```

## Implementation Details

### Streaming Technique

Streaming endpoints use Dream's `response.stream_response()`:

```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder
import gleam/erlang/process

pub fn stream_fast(...) -> Response {
  let stream =
    yielder.range(1, 10)
    |> yielder.map(fn(n) {
      process.sleep(100)
      let line = "Chunk " <> int.to_string(n) <> "\n"
      bit_array.from_string(line)
    })

  stream_response(status.ok, stream, "text/plain")
}
```

### Non-Streaming Technique

Non-streaming endpoints use standard `json_response()` and `text_response()`:

```gleam
import dream/http/response.{json_response}
import dream/http/status
import gleam/json

pub fn get(...) -> Response {
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

## See Also

- [Dream Streaming Guide](../../docs/guides/streaming.md)
- [HTTP Client Module](../../modules/http_client/)
- [Streaming Capabilities Example](../streaming_capabilities/)
