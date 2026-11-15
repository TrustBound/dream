# Streaming Capabilities Example

**Complete showcase of Dream's streaming features.**

This example demonstrates all streaming patterns in Dream:
1. **Ingress Streaming**: Receive large uploads without buffering
2. **Egress Streaming**: Send large responses without buffering  
3. **Bi-Directional Streaming**: Transform data both ways
4. **Streaming Middleware**: Process chunks as they flow
5. **Proxy Streaming**: Forward streams from external sources

## Quick Start

```bash
make run
```

Server starts on `http://localhost:3000`

## Endpoints

### 1. Ingress Streaming (Upload)

Stream a file to the server. Server counts bytes without loading into RAM.

```bash
# Create a test file
echo "Hello World from a large file" > test.txt

# Upload (streaming - no buffering)
curl -X POST --data-binary @test.txt http://localhost:3000/upload

# Response: "Uploaded 29 bytes successfully"
```

**How it works:**
- Route marked with `stream_route(method: Post, ...)` (not `route(...)`)
- `request.stream` is `Some(Yielder(BitArray))`
- Controller processes chunks without buffering
- Memory usage stays constant

### 2. Egress Streaming (Download)

Stream generated data from server.

```bash
curl http://localhost:3000/download > output.txt
```

**How it works:**
- Controller returns `stream_response(status, stream, content_type)`
- Yielder generates 1000 lines on demand
- Client receives chunks as they're generated
- Transfer-Encoding: chunked (automatic)

### 3. Bi-Directional Transformation

Send data, middleware transforms it both ways.

```bash
curl -X POST -d "hello world" http://localhost:3000/echo_transform

# Output: HELLO_WORLD
```

**Data flow:**
1. Client sends: `"hello world"`
2. Incoming middleware: `"hello world"` → `"HELLO WORLD"` (uppercase)
3. Controller echoes stream
4. Outgoing middleware: `"HELLO WORLD"` → `"HELLO_WORLD"` (replace spaces)
5. Client receives: `"HELLO_WORLD"`

### 4. Proxy Streaming

Stream from simulated "upstream" source.

```bash
curl http://localhost:3000/proxy
```

**How it works:**
- Simulates streaming from external API
- No buffering between upstream and client
- Memory efficient for large proxied responses

## Testing

### Run Integration Tests

```bash
make test-integration
```

This will:
1. Build the Gleam application
2. Start the server on port 3000
3. Run Cucumber tests against all endpoints
4. Verify streaming behavior
5. Stop the server

### Test Coverage

All streaming patterns are tested:
- ✅ Ingress streaming (upload with size validation)
- ✅ Egress streaming (download with line count)
- ✅ Bi-directional transformation (input → output transform)
- ✅ Empty body handling
- ✅ Error responses

## Code Structure

```
examples/streaming_capabilities/
├── gleam.toml                           # Project config
├── Makefile                             # Build commands
├── src/
│   ├── main.gleam                       # Server entry point
│   ├── router.gleam                     # Route definitions
│   ├── services.gleam                   # Empty services
│   ├── controllers/
│   │   └── stream_controller.gleam     # Streaming controllers
│   └── middleware/
│       └── transform_middleware.gleam  # Streaming middleware
└── test/
    └── integration/                     # Cucumber integration tests
```

## Key Concepts

### Streaming Routes

A route must enable request streaming. `stream_route` gives the controller the body as a `Yielder(BitArray)` in `request.stream`. `route` reads the whole body first. A streaming response does not need `stream_route`: `/download` is a plain `route`.

#### Router <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/router.gleam#L8-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create() -> Router(EmptyContext, Services) {
  router()
  // 1. Ingress Streaming (Uploads)
  // POST /upload - Streams data directly to "disk" (simulated)
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: stream_controller.upload,
    middleware: [],
  )
  // 2. Egress Streaming (Downloads)
  // GET /download - Streams generated data back to client
  |> router.route(
    method: Get,
    path: "/download",
    controller: stream_controller.download,
    middleware: [],
  )
  // 3. Bi-Directional Streaming Middleware
  // POST /echo_transform - Uppercase IN -> Underscore OUT
  |> stream_route(
    method: Post,
    path: "/echo_transform",
    controller: stream_controller.echo_transform,
    middleware: [
      transform_middleware.uppercase_incoming,
      transform_middleware.replace_space_outgoing,
    ],
  )
  // 4. Proxy Streaming
  // GET /proxy - Streams from external API to client
  |> router.route(
    method: Get,
    path: "/proxy",
    controller: stream_controller.proxy,
    middleware: [],
  )
}
```

### Request Streaming

The controller folds over the chunks, so it never holds the whole body in memory:

#### Upload controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L14-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Ingress Streaming: Receives a stream and "saves" it (logs size)
pub fn upload(
  request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  case request.stream {
    Some(stream) -> {
      // Consume the stream "saving" it
      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    }
    None -> text_response(status.bad_request, "Expected streaming request body")
  }
}
```

#### Count the bytes in one chunk <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L87-L91"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn accumulate_chunk_size(acc: Int, chunk: BitArray) -> Int {
  let size = bit_array.byte_size(chunk)
  // Simulate saving to disk
  acc + size
}
```

### Response Streaming

The controller makes the chunks on demand and gives the yielder to `stream_response`:

#### Download controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L34-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Egress Streaming: Generates data on the fly and streams it out
pub fn download(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  // Generate a stream of numbers
  let stream = yielder.range(1, 1000) |> yielder.map(create_line)

  stream_response(status.ok, stream, "text/plain")
}
```

#### Make one chunk <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L93-L96"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn create_line(n: Int) -> BitArray {
  let line = "Line " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}
```

### Streaming Middleware

Middleware can transform streams. `uppercase_incoming` changes each request chunk before the controller reads it. `replace_space_outgoing` in the same file changes each response chunk:

#### Uppercase the request stream <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/middleware/transform_middleware.gleam#L10-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Middleware that converts all incoming stream chunks to uppercase
pub fn uppercase_incoming(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let transformed_stream =
        stream
        |> yielder.map(uppercase_chunk)

      let new_request = Request(..request, stream: Some(transformed_stream))
      next(new_request, context, services)
    }
    // If not a stream or empty, pass through unchanged
    None -> next(request, context, services)
  }
}
```

## Memory Efficiency

### Buffered vs Streaming

**Buffered (regular routes):**
- Loads entire request body into memory as `String`
- Good for: JSON APIs, form submissions (< 1MB)
- Memory: O(request_size)

**Streaming (streaming routes):**
- Processes request in chunks
- Good for: File uploads, large payloads (> 1MB)
- Memory: O(chunk_size) - constant!

### Example: 100MB File Upload

A route made with `route` loads the full body before the controller runs, so a 100MB upload uses 100MB of memory. The example's `/download` route is a buffered route:

#### Buffered route <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/router.gleam#L20-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  |> router.route(
    method: Get,
    path: "/download",
    controller: stream_controller.download,
    middleware: [],
  )
```

A route made with `stream_route` gives the body in chunks (64KB by default), so memory use stays the same for any upload size. The example's `/upload` route is a streaming route:

#### Streaming route <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/router.gleam#L12-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: stream_controller.upload,
    middleware: [],
  )
```

## Best Practices

### 1. Use Streaming for Large Data

Do not build a large response as one `String` and send it with `text_response`: the full response is then in memory. Give `stream_response` a yielder instead, so memory use stays constant:

#### Stream the response <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L40-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // Generate a stream of numbers
  let stream = yielder.range(1, 1000) |> yielder.map(create_line)

  stream_response(status.ok, stream, "text/plain")
```

### 2. Handle Empty Streams

An upload can have an empty body. A fold over an empty stream gives its start value, so the upload controller replies "Uploaded 0 bytes successfully" with no special case:

#### Fold handles an empty stream <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L23-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
```

### 3. Validate Chunks Early

Check each chunk when it arrives, and decide what to do with bad input. `uppercase_chunk` changes a chunk only when it is valid UTF-8, and passes other chunks through unchanged:

#### Check one chunk <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/streaming_capabilities/src/middleware/transform_middleware.gleam#L53-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn uppercase_chunk(chunk: BitArray) -> BitArray {
  case bit_array.to_string(chunk) {
    Ok(text) -> {
      text
      |> string.uppercase
      |> bit_array.from_string
    }
    // If invalid UTF-8, pass through (or handle error)
    Error(_) -> chunk
  }
}
```

## Use Cases

### File Uploads
- User avatars
- Document uploads
- Video uploads
- Batch imports

### Large Exports
- CSV exports (millions of rows)
- Log file exports
- Database dumps
- Report generation

### Real-Time Data
- Server-Sent Events
- Progress updates
- Log tailing
- Live metrics

### Proxying
- API gateway patterns
- Media streaming
- Download acceleration
- Caching proxies

## Learn More

- **[Streaming Guide](../../docs/guides/streaming.md)** - Complete streaming documentation
- **[How It Works](../../docs/concepts/how-it-works.md)** - Request flow and streaming
- **[Testing Guide](../../docs/contributing/testing.md)** - Test streaming endpoints

## Related Examples

- [`streaming`](../streaming/) - HTTP client streaming
- [`multi_format`](../multi_format/) - CSV export streaming  
- [`tasks`](../tasks/) - Production app with various features
- [`database`](../database/) - Database operations

---

**This example showcases Dream's streaming capabilities. Study the code to understand memory-efficient data handling patterns.**
