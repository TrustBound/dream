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

Routes must explicitly enable streaming:

```gleam
import dream/router.{route, router, stream_route}
import dream/http/request.{Post}

pub fn create() {
  router
  // Regular route - body buffered as String
  |> route(method: Post, path: "/upload", controller: buffered_upload, middleware: [])
  
  // Streaming route - body as Yielder(BitArray)
  |> stream_route(method: Post, path: "/upload_stream", controller: streaming_upload, middleware: [])
}
```

### Request Streaming

```gleam
pub fn upload(request: Request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      // Process chunks without loading all into memory
      let total_bytes =
        stream
        |> yielder.fold(0, fn(acc, chunk) {
          acc + bit_array.byte_size(chunk)
        })
      
      text_response(status.ok, "Uploaded " <> int.to_string(total_bytes) <> " bytes")
    }
    None -> text_response(status.bad_request, "Expected streaming request")
  }
}
```

### Response Streaming

```gleam
pub fn download(request: Request, context, services) -> Response {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(fn(n) {
      let line = "Line " <> int.to_string(n) <> "\n"
      <<line:utf8>>
    })
  
  stream_response(status.ok, stream, "text/plain")
}
```

### Streaming Middleware

Middleware can transform streams:

```gleam
pub fn uppercase_incoming(request, context, services, next) {
  case request.stream {
    Some(stream) -> {
      let uppercase_stream =
        stream
        |> yielder.map(fn(chunk) {
          chunk
          |> bit_array.to_string()
          |> result.unwrap("")
          |> string.uppercase()
          |> bit_array.from_string()
        })
      
      let transformed_request = Request(..request, stream: Some(uppercase_stream))
      next(transformed_request, context, services)
    }
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

**Buffered route:**
```gleam
router.post("/upload", upload, [])
// Memory usage: 100MB (full body loaded)
```

**Streaming route:**
```gleam
router
|> stream_route(method: Post, path: "/upload", controller: upload, middleware: [])
// Memory usage: 64KB (default chunk size)
```

## Best Practices

### 1. Use Streaming for Large Data

```gleam
// DON'T: Buffer large responses
let all_products = query_products(db)  // 1M rows
let csv = products_to_csv(all_products)  // ~100MB string
text_response(status.ok, csv)  // Entire response in memory

// DO: Stream large responses
let product_stream = query_products_stream(db)  // Yielder
let csv_stream = products_to_csv_stream(product_stream)
stream_response(status.ok, csv_stream, "text/csv")  // Constant memory
```

### 2. Handle Empty Streams

```gleam
pub fn upload(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      case yielder.first(stream) {
        Ok(_) -> process_stream(stream)
        Error(_) -> text_response(status.ok, "Uploaded 0 bytes successfully")
      }
    }
    None -> text_response(status.bad_request, "Expected streaming request")
  }
}
```

### 3. Set Appropriate Timeouts

```gleam
// In main.gleam
server.new()
  |> router(app_router.create())
  |> read_timeout(300_000)  // 5 minutes for large uploads
  |> listen(3000)
```

### 4. Validate Chunks Early

```gleam
pub fn upload_image(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      // Validate first chunk for magic bytes
      case validate_first_chunk(stream) {
        Ok(valid_stream) -> save_image(valid_stream, services)
        Error(_) -> text_response(status.unprocessable_entity, "Invalid image")
      }
    }
    None -> text_response(status.bad_request, "Expected image upload")
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
