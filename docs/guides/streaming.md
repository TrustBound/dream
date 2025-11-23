# Streaming in Dream

Stream large files, real-time data, and transform data on-the-fly without loading everything into memory.

## Table of Contents

- [Overview](#overview)
- [Egress Streaming (Sending Streams)](#egress-streaming-sending-streams)
- [Ingress Streaming (Receiving Streams)](#ingress-streaming-receiving-streams)
- [Streaming Middleware](#streaming-middleware)
- [Server-Sent Events (SSE)](#server-sent-events-sse)
- [Best Practices](#best-practices)
- [Working Examples](#working-examples)

## Overview

Dream supports streaming in both directions:

- **Egress**: Stream responses to clients (downloads, SSE, CSV exports)
- **Ingress**: Stream requests from clients (file uploads, large payloads)

Streaming uses Gleam's `Yielder` type for lazy, memory-efficient data processing.

### When to Use Streaming

**Use streaming for:**
- Large files (> 1MB)
- Real-time data (AI responses, logs, events)
- CSV exports from database
- File uploads
- Proxying external APIs

**Use buffering for:**
- Small responses (< 1MB)
- JSON APIs
- Form submissions
- Most HTTP requests

## Egress Streaming (Sending Streams)

### Basic Streaming Response

Stream data to the client without loading it all into memory:

```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder
import gleam/int

pub fn download(request, context, services) {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(number_to_line)
  
  stream_response(status.ok, stream, "text/plain")
}

fn number_to_line(n: Int) -> BitArray {
  let line = "Line " <> int.to_string(n) <> "\n"
  <<line:utf8>>
}
```

**Key points:**
- `stream_response(status, stream, content_type)` creates a streaming response
- Stream is `Yielder(BitArray)` - generates chunks on demand
- Client receives chunks as they're generated

### CSV Export Streaming

Stream database results as CSV without loading entire table:

```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder
import gleam/float
import gleam/int

pub fn export_products(request, context, services) {
  let result = {
    let db = services.database.connection
    product_operations.list_products(db)
  }
  
  result
  |> result.map(products_to_csv_stream)
  |> result.map(create_csv_response)
  |> result.unwrap_both(handle_error)
}

fn create_csv_response(stream: yielder.Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}

fn products_to_csv_stream(products: List(Product)) -> yielder.Yielder(BitArray) {
  let header = "id,name,price,stock\n"
  
  yielder.from_list([header, ..list.map(products, product_to_csv_row)])
  |> yielder.map(string_to_bitarray)
}

fn string_to_bitarray(row: String) -> BitArray {
  <<row:utf8>>
}

fn product_to_csv_row(p: Product) -> String {
  int.to_string(p.id)
  <> "," <> p.name
  <> "," <> float.to_string(p.price)
  <> "," <> int.to_string(p.stock)
  <> "\n"
}
```

### Large File Streaming

Stream files from disk without loading into memory:

```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder
import simplifile

pub fn download_file(request, context, services) {
  simplifile.read_bits("large_file.bin")
  |> result.map(create_file_stream)
  |> result.map(create_binary_stream_response)
  |> result.unwrap(response.empty_response(status.not_found))
}

fn create_file_stream(file_data: BitArray) -> yielder.Yielder(BitArray) {
  yielder.from_list([file_data])
}

fn create_binary_stream_response(stream: yielder.Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "application/octet-stream")
}
```

## Ingress Streaming (Receiving Streams)

### Enable Streaming on a Route

Routes must explicitly enable streaming to receive streamed request bodies:

```gleam
import dream/router.{route, router, stream_route}
import dream/http/request.{Post}

pub fn create_router() {
  router
  // Regular route - body is buffered as String
  |> route(method: Post, path: "/upload", controller: controllers.upload_buffered, middleware: [])
  
  // Streaming route - body is available as Yielder(BitArray)
  |> stream_route(method: Post, path: "/upload_stream", controller: controllers.upload_stream, middleware: [])
}
```

**Key difference:**
- Regular routes: `request.body` is `String`, `request.stream` is `None`
- Streaming routes: `request.body` is `""`, `request.stream` is `Some(Yielder(BitArray))`

### Process Streaming Uploads

```gleam
import dream/http/request.{type Request}
import dream/http/response.{text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/option.{None, Some}
import gleam/yielder

pub fn upload_stream(request: Request, context, services) -> Response {
  request.stream
  |> option.map(count_stream_bytes)
  |> option.map(create_upload_success_response)
  |> option.unwrap(text_response(status.bad_request, "Expected streaming request body"))
}

fn count_stream_bytes(stream: yielder.Yielder(BitArray)) -> Int {
  yielder.fold(stream, 0, add_chunk_size)
}

fn add_chunk_size(acc: Int, chunk: BitArray) -> Int {
  acc + bit_array.byte_size(chunk)
}

fn create_upload_success_response(total_bytes: Int) -> Response {
  text_response(
    status.ok,
    "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully"
  )
}
```

### Saving Streamed Files

```gleam
import simplifile
import gleam/result

pub fn save_upload(request, context, services) -> Response {
  request.stream
  |> option.map(save_stream_to_file)
  |> option.map(handle_save_result)
  |> option.unwrap(text_response(status.bad_request, "Expected streaming request"))
}

fn save_stream_to_file(stream: yielder.Yielder(BitArray)) -> Result(Nil, simplifile.FileError) {
  use file_handle <- result.try(simplifile.create("uploads/file.bin"))
  use _ <- result.try(write_all_chunks(stream, file_handle))
  Ok(Nil)
}

fn write_all_chunks(stream: yielder.Yielder(BitArray), file_handle) -> Result(Nil, simplifile.FileError) {
  yielder.fold(stream, Ok(Nil), fold_write_chunk(_, _, file_handle))
}

fn fold_write_chunk(result: Result(Nil, simplifile.FileError), chunk: BitArray, file_handle) -> Result(Nil, simplifile.FileError) {
  use _ <- result.try(result)
  simplifile.append_bits(file_handle, chunk)
}

fn handle_save_result(result: Result(Nil, simplifile.FileError)) -> Response {
  case result {
    Ok(_) -> text_response(status.ok, "File saved successfully")
    Error(_) -> text_response(status.internal_server_error, "Failed to save file")
  }
}
```

## Streaming Middleware

### Transform Request Stream

Middleware can transform streaming request bodies:

```gleam
import dream/http/request.{Request}
import dream/http/response.{type Response}
import dream/router.{Middleware}
import gleam/bit_array
import gleam/option.{Some}
import gleam/string
import gleam/yielder

pub fn uppercase_incoming() -> Middleware(context, services) {
  Middleware(uppercase_incoming_handler)
}

fn uppercase_incoming_handler(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let uppercase_stream = transform_stream_to_uppercase(stream)
      let transformed_request = Request(..request, stream: Some(uppercase_stream))
      next(transformed_request, context, services)
    }
    None -> next(request, context, services)
  }
}

fn transform_stream_to_uppercase(stream: yielder.Yielder(BitArray)) -> yielder.Yielder(BitArray) {
  yielder.map(stream, uppercase_chunk)
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  chunk
  |> bit_array.to_string()
  |> result.unwrap("")
  |> string.uppercase()
  |> bit_array.from_string()
}
```

### Transform Response Stream

Middleware can also transform streaming responses:

```gleam
pub fn replace_space_outgoing() -> Middleware(context, services) {
  Middleware(replace_space_outgoing_handler)
}

fn replace_space_outgoing_handler(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)
  
  transform_response_stream(response)
}

fn transform_response_stream(response: Response) -> Response {
  case response.body {
    Stream(stream) -> Response(..response, body: Stream(yielder.map(stream, replace_space_chunk)))
    _ -> response
  }
}

fn replace_space_chunk(chunk: BitArray) -> BitArray {
  chunk
  |> bit_array.to_string()
  |> result.unwrap("")
  |> string.replace(" ", "_")
  |> bit_array.from_string()
}
```

### Bi-Directional Streaming Example

```gleam
import dream/router.{post_stream, router}

pub fn create_router() {
  router
  |> post_stream(
    "/transform",
    stream_controller.echo,
    [
      transform_middleware.uppercase_incoming(),
      transform_middleware.replace_space_outgoing(),
    ]
  )
}

// Controller just echoes the stream
pub fn echo(request: Request, context, services) -> Response {
  case request.stream {
    Some(stream) -> stream_response(status.ok, stream, "text/plain")
    None -> text_response(status.bad_request, "Expected streaming request")
  }
}
```

**Flow:**
1. Client sends: `"hello world"`
2. Incoming middleware: `"hello world"` → `"HELLO WORLD"`
3. Controller echoes stream
4. Outgoing middleware: `"HELLO WORLD"` → `"HELLO_WORLD"`
5. Client receives: `"HELLO_WORLD"`

## Server-Sent Events (SSE)

### Basic SSE Endpoint

```gleam
import dream/http/response.{sse_response}
import dream/http/status
import gleam/yielder
import gleam/int

pub fn events(request, context, services) {
  let event_stream =
    yielder.range(1, 100)
    |> yielder.map(number_to_sse_event)
  
  sse_response(status.ok, event_stream, "text/event-stream")
}

fn number_to_sse_event(n: Int) -> BitArray {
  let data = "data: {\"count\": " <> int.to_string(n) <> "}\n\n"
  <<data:utf8>>
}
```

### SSE Event Format

```
data: {"type": "message", "text": "Hello"}

data: {"type": "update", "count": 42}

data: {"type": "complete"}

```

Each event:
- Starts with `data: `
- Contains JSON (or any text)
- Ends with double newline (`\n\n`)

### SSE with Event IDs

```gleam
fn format_sse_event(id: Int, data: String) -> BitArray {
  let event = 
    "id: " <> int.to_string(id) <> "\n"
    <> "data: " <> data <> "\n\n"
  <<event:utf8>>
}

pub fn events_with_ids(request, context, services) {
  let stream =
    services.event_source.subscribe()
    |> yielder.index()
    |> yielder.map(format_indexed_event)
  
  sse_response(status.ok, stream, "text/event-stream")
}

fn format_indexed_event(pair: #(Event, Int)) -> BitArray {
  let #(event, index) = pair
  format_sse_event(index, event_to_json(event))
}
```

## Chunked Transfer Encoding

Dream automatically uses HTTP chunked transfer encoding for streaming responses.

**How it works:**

1. Controller returns `stream_response(...)`
2. Dream sends headers with `Transfer-Encoding: chunked`
3. Each yielder value becomes a chunk
4. Client receives chunks as they're generated
5. Connection closes when yielder completes

**No configuration needed** - it's automatic for streaming responses.

## Best Practices

### 1. Use Appropriate Buffer Sizes

```gleam
// Small chunks for real-time feel (named function)
yielder.range(1, 1000)
|> yielder.map(create_small_chunk)

// Larger chunks for efficiency
file_stream
|> yielder.sized_chunk(65_536)  // 64KB chunks

fn create_small_chunk(n: Int) -> BitArray {
  <<n:8>>  // ~10 bytes per chunk
}
```

### 2. Handle Errors Gracefully

```gleam
pub fn upload_stream(request, context, services) -> Response {
  request.stream
  |> option.map(process_stream_safely)
  |> option.map(handle_upload_result)
  |> option.unwrap(text_response(status.bad_request, "Expected streaming request"))
}

fn process_stream_safely(stream: yielder.Yielder(BitArray)) -> Result(String, Error) {
  stream
  |> yielder.try_fold(0, validate_and_add_chunk)
  |> result.map(format_bytes_message)
}

fn validate_and_add_chunk(acc: Int, chunk: BitArray) -> Result(Int, Error) {
  use size <- result.try(validate_chunk(chunk))
  Ok(acc + size)
}

fn format_bytes_message(total: Int) -> String {
  "Processed " <> int.to_string(total) <> " bytes"
}

fn handle_upload_result(result: Result(String, Error)) -> Response {
  result
  |> result.map(create_success_response)
  |> result.unwrap_error(text_response(status.internal_server_error, "Upload failed"))
}

fn create_success_response(msg: String) -> Response {
  text_response(status.ok, msg)
}
```

### 3. Set Timeouts for Streaming Routes

```gleam
import dream/servers/mist/server.{max_body_size, read_timeout}

pub fn main() {
  server.new()
  |> router(app_router.create())
  |> max_body_size(100_000_000)  // 100MB max
  |> read_timeout(300_000)       // 5 minutes
  |> listen(3000)
}
```

### 4. Use Streaming Routes Explicitly

```gleam
// DON'T: Assume all POST routes are streaming
router
|> route(method: Post, path: "/upload", controller: upload_handler, middleware: [])  // Body buffered as String

// DO: Explicitly mark streaming routes
router
|> stream_route(method: Post, path: "/upload", controller: upload_handler, middleware: [])  // Body as Yielder
```

### 5. Clean Up Resources

```gleam
pub fn upload_to_s3(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      let result =
        stream
        |> upload_to_s3_bucket(services.s3_client)
      
      case result {
        Ok(url) -> json_response(status.created, "{\"url\": \"" <> url <> "\"}")
        Error(err) -> {
          // Clean up partial upload
          cleanup_failed_upload(services.s3_client)
          handle_error(err)
        }
      }
    }
    None -> text_response(status.bad_request, "Expected streaming upload")
  }
}
```

## Streaming vs Buffering

### Request Handling

| Feature | Buffered Route | Streaming Route |
|---------|----------------|-----------------|
| Route | `route(...)` | `stream_route(...)` |
| `request.body` | Full body as `String` | Empty `""` |
| `request.stream` | `None` | `Some(Yielder(BitArray))` |
| Memory | Loads full body | Processes chunks |
| Max size | Limited by `max_body_size` | Can be unlimited |
| Use for | Forms, JSON APIs | File uploads, large payloads |

### Response Types

```gleam
import dream/http/response.{Text, Bytes, Stream}

// Buffered text response
Text("Hello, World!")  // Entire response in memory

// Buffered binary response
Bytes(image_data)  // Entire file in memory

// Streaming response
Stream(file_chunks)  // Chunks generated on demand
```

## Common Patterns

### Pattern 1: CSV Export

```gleam
pub fn export_users_csv(request, context, services) {
  let result = {
    let db = services.database.connection
    user_operations.list_all(db)
  }
  
  result
  |> result.map(users_to_csv_stream)
  |> result.map(create_csv_stream_response)
  |> result.unwrap_both(handle_error)
}

fn users_to_csv_stream(users: List(User)) -> yielder.Yielder(BitArray) {
  yielder.from_list(["id,name,email\n", ..user_to_csv_rows(users)])
  |> yielder.map(string_to_bitarray)
}

fn create_csv_stream_response(stream: yielder.Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}
```

### Pattern 2: Progress Updates

```gleam
pub fn long_running_task(request, context, services) {
  let progress_stream =
    services.task_queue
    |> execute_with_progress()
    |> yielder.map(progress_to_sse_event)
  
  sse_response(status.ok, progress_stream, "text/event-stream")
}

fn progress_to_sse_event(percent: Int) -> BitArray {
  let msg = "data: {\"progress\": " <> int.to_string(percent) <> "}\n\n"
  <<msg:utf8>>
}
```

### Pattern 3: File Upload with Validation

```gleam
pub fn upload_image(request, context, services) -> Response {
  request.stream
  |> option.map(validate_and_save_with_storage(_, services.storage))
  |> option.map(map_validation_result_to_response)
  |> option.unwrap(text_response(status.bad_request, "Expected file upload"))
}

fn validate_and_save_with_storage(stream: yielder.Yielder(BitArray), storage) -> Result(String, Error) {
  validate_and_save_image(stream, storage)
}

fn validate_and_save_image(stream: yielder.Yielder(BitArray), storage) -> Result(String, Error) {
  use first_step <- result.try(get_first_chunk(stream))
  use full_stream <- result.try(validate_image_header(first_step))
  save_to_storage(full_stream, storage)
}

fn get_first_chunk(stream: yielder.Yielder(BitArray)) -> Result(yielder.Step(BitArray, fn() -> yielder.Yielder(BitArray)), Error) {
  case yielder.step(stream) {
    yielder.Done -> Error(EmptyUpload)
    step -> Ok(step)
  }
}

fn validate_image_header(step: yielder.Step(BitArray, fn() -> yielder.Yielder(BitArray))) -> Result(yielder.Yielder(BitArray), Error) {
  case step {
    yielder.Next(data, continuation) -> {
      use _ <- result.try(check_is_valid_image(data))
      let full_stream = yielder.append(yielder.single(data), continuation())
      Ok(full_stream)
    }
    yielder.Done -> Error(EmptyUpload)
  }
}

fn check_is_valid_image(data: BitArray) -> Result(Nil, Error) {
  case is_valid_image(data) {
    True -> Ok(Nil)
    False -> Error(InvalidFileType)
  }
}

fn map_validation_result_to_response(result: Result(String, Error)) -> Response {
  case result {
    Ok(file_id) -> json_response(status.created, "{\"file_id\": \"" <> file_id <> "\"}")
    Error(InvalidFileType) -> text_response(status.unprocessable_entity, "Invalid image format")
    Error(_) -> text_response(status.internal_server_error, "Upload failed")
  }
}
```

## Working Examples

### Simple Streaming

See [`examples/streaming/`](../../examples/streaming/) for HTTP client streaming.

### Advanced Streaming

See [`examples/streaming_capabilities/`](../../examples/streaming_capabilities/) for:
- **Ingress streaming**: File uploads with byte counting
- **Egress streaming**: Generate and stream 1000 lines
- **Bi-directional streaming**: Transform data both ways
- **Streaming middleware**: Uppercase input, replace spaces in output
- **Proxy streaming**: Stream from external API

### Multi-Format Streaming

See [`examples/multi_format/`](../../examples/multi_format/) for:
- CSV export as a stream
- Different formats from same data
- Streaming with database queries

## Performance Considerations

### Memory Usage

**Buffered response:**
```gleam
// Loads entire CSV into memory (BAD for large exports)
let all_users = query_all_users(db)  // List of 1 million users
let csv = users_to_csv(all_users)    // ~100MB string in memory
text_response(status.ok, csv)
```

**Streaming response:**
```gleam
// Generates CSV rows on demand (GOOD for large exports)
let user_stream = query_all_users(db)  // Returns yielder
let csv_stream = users_to_csv_stream(user_stream)  // Lazy transform
stream_response(status.ok, csv_stream, "text/csv")
```

### Backpressure

Yielders provide natural backpressure:
- Client stops reading → Server stops generating
- No unbounded buffering
- Memory stays constant regardless of data size

### Chunk Sizing

```gleam
// Small chunks: More responsive, more overhead
yielder.repeat(data) |> yielder.take(1000)  // 1000 tiny chunks

// Large chunks: Less responsive, more efficient
yielder.sized_chunk(stream, 65_536)  // 64KB chunks (recommended)

// Adaptive chunking based on data
yielder.from_list(rows)  // One chunk per database row
```

## Testing Streaming

### Unit Tests

```gleam
import gleeunit/should

pub fn stream_response_generates_chunks_test() {
  // Arrange
  let stream =
    yielder.range(1, 3)
    |> yielder.map(int_to_byte)
  
  // Act
  let response = stream_response(status.ok, stream, "application/octet-stream")
  
  // Assert
  case response.body {
    Stream(s) -> {
      let chunks = yielder.to_list(s)
      list.length(chunks) |> should.equal(3)
    }
    _ -> should.fail()
  }
}

fn int_to_byte(n: Int) -> BitArray {
  <<n:8>>
}
```

### Integration Tests

```gherkin
Feature: Streaming Example

  Scenario: Streaming response contains multiple lines
    When I send a GET request to "/download"
    Then the response status should be 200
    And the response should have at least 100 lines
```

See [Testing Guide](testing.md) for more examples.

## Common Pitfalls

### ❌ Don't Consume Stream Twice

```gleam
// BAD: Stream can only be consumed once
let stream = yielder.range(1, 100)
let count = yielder.length(stream)  // Consumes stream
stream_response(status.ok, stream, "text/plain")  // Stream is exhausted!
```

### ❌ Don't Mix Streaming and Buffering

```gleam
// BAD: Defeats the purpose of streaming
let stream = yielder.from_list(data)
let all_data = yielder.to_list(stream)  // Loads everything into memory
stream_response(status.ok, yielder.from_list(all_data), "text/plain")

// GOOD: Keep it lazy
let stream = yielder.from_list(data)
stream_response(status.ok, stream, "text/plain")
```

### ❌ Don't Forget Error Handling

```gleam
// BAD: No error handling
pub fn upload(request, context, services) -> Response {
  let Some(stream) = request.stream  // Panics if None!
  save_stream(stream)
}

// GOOD: Handle all cases
pub fn upload(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> save_stream(stream)
    None -> text_response(status.bad_request, "Expected streaming upload")
  }
}
```

## API Reference

### Response Builders

```gleam
// Stream with custom content type
stream_response(status: Int, stream: Yielder(BitArray), content_type: String) -> Response

// Server-Sent Events (includes SSE headers)
sse_response(status: Int, stream: Yielder(BitArray), content_type: String) -> Response
```

### Router Functions

```gleam
// Enable streaming for any HTTP method
stream_route(
  method: Method,
  path: String,
  controller: Controller,
  middleware: List(Middleware)
) -> Router
```

### Request Fields

```gleam
type Request {
  Request(
    ...
    body: String,                         // Buffered body (empty for streaming routes)
    stream: Option(Yielder(BitArray)),    // Streaming body (Some for streaming routes)
    ...
  )
}
```

### Response Body Types

```gleam
type ResponseBody {
  Text(String)                      // Buffered text response
  Bytes(BitArray)                   // Buffered binary response
  Stream(Yielder(BitArray))         // Streaming response
}
```

## See Also

- [Multiple Formats Guide](multiple-formats.md) - Different response formats
- [File Uploads Guide](file-uploads.md) - Multipart form handling
- [Streaming Example](../../examples/streaming/) - HTTP client streaming
- [Streaming Capabilities Example](../../examples/streaming_capabilities/) - Advanced streaming
- [Multi-Format Example](../../examples/multi_format/) - CSV streaming with database
