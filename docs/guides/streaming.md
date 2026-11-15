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

#### Stream 1000 lines <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_download.gleam#L5-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response}
import dream/http/status
import gleam/int
import gleam/yielder

pub fn download(_request: Request, _context, _services) -> Response {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(number_to_line)

  stream_response(status.ok, stream, "text/plain")
}

fn number_to_line(number: Int) -> BitArray {
  let line = "Line " <> int.to_string(number) <> "\n"
  <<line:utf8>>
}
```

**Key points:**
- `stream_response(status, stream, content_type)` creates a streaming response
- Stream is `Yielder(BitArray)` - generates chunks on demand
- Client receives chunks as they're generated

### CSV Export Streaming

Stream products as CSV. Dream makes each row when the client reads it, so the
CSV is never one big string in memory. Here `list_products` stands in for a
database query:

#### Stream products as CSV <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_csv_export.gleam#L6-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/float
import gleam/int
import gleam/result
import gleam/yielder

pub type Product {
  Product(id: Int, name: String, price: Float, stock: Int)
}

pub type Services {
  Services(list_products: fn() -> Result(List(Product), String))
}

pub fn export_products(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  services.list_products()
  |> result.map(products_to_csv_stream)
  |> result.map(create_csv_response)
  |> result.lazy_unwrap(create_error_response)
}

fn create_csv_response(stream: yielder.Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}

fn create_error_response() -> Response {
  text_response(status.internal_server_error, "Could not load products")
}

fn products_to_csv_stream(
  products: List(Product),
) -> yielder.Yielder(BitArray) {
  yielder.from_list(products)
  |> yielder.map(product_to_csv_row)
  |> yielder.prepend("id,name,price,stock\n")
  |> yielder.map(bit_array.from_string)
}

fn product_to_csv_row(product: Product) -> String {
  int.to_string(product.id)
  <> ","
  <> product.name
  <> ","
  <> float.to_string(product.price)
  <> ","
  <> int.to_string(product.stock)
  <> "\n"
}
```

### Large File Streaming

Send a file from disk as a stream of 64 KB chunks. `simplifile.read_bits`
reads the whole file into memory first, so use this for files that fit in
memory:

#### Send a file in 64 KB chunks <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_file_download.gleam#L6-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response, empty_response, stream_response}
import dream/http/status
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(file_path: String)
}

pub fn download_file(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  simplifile.read_bits(services.file_path)
  |> result.map(create_file_stream)
  |> result.map(create_binary_stream_response)
  |> result.unwrap(empty_response(status.not_found))
}

fn create_file_stream(file_data: BitArray) -> yielder.Yielder(BitArray) {
  yielder.unfold(file_data, take_next_chunk)
}

fn take_next_chunk(remaining: BitArray) -> yielder.Step(BitArray, BitArray) {
  case remaining {
    <<>> -> yielder.Done
    <<chunk:bytes-size(65_536), rest:bytes>> -> yielder.Next(chunk, rest)
    last_chunk -> yielder.Next(last_chunk, <<>>)
  }
}

fn create_binary_stream_response(
  stream: yielder.Yielder(BitArray),
) -> Response {
  stream_response(status.ok, stream, "application/octet-stream")
}
```

## Ingress Streaming (Receiving Streams)

### Enable Streaming on a Route

Routes must explicitly enable streaming to receive streamed request bodies:

#### Buffered and streaming routes <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_ingress.gleam#L6-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, Bytes, Post, Put, Stream, Text}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/string
import gleam/yielder

pub fn create_router() -> Router(context, services) {
  router()
  // Regular route: the body is buffered as a String
  |> route(
    method: Post,
    path: "/upload",
    controller: upload_buffered,
    middleware: [],
  )
  // Streaming route: the body is available as a Yielder(BitArray)
  |> stream_route(
    method: Post,
    path: "/upload_stream",
    controller: upload_stream,
    middleware: [],
  )
}
```

**Key difference:**
- Regular routes: `request.body` is `Text(String)` for a UTF-8 body, or
  `Bytes(BitArray)` with the exact bytes for any other body
- Streaming routes: `request.body` is `Stream(Yielder(BitArray))`

### Process Streaming Uploads <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_ingress.gleam#L42-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn upload_stream(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      count_stream_bytes(stream)
      |> create_upload_success_response
    _ -> text_response(status.bad_request, "Expected streaming request body")
  }
}

fn count_stream_bytes(stream: yielder.Yielder(BitArray)) -> Int {
  yielder.fold(stream, 0, add_chunk_size)
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}

fn create_upload_success_response(total_bytes: Int) -> Response {
  text_response(
    status.ok,
    "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
  )
}
```

### Saving Streamed Files <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_saving.gleam#L6-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String, max_upload_bytes: Int)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) ->
      save_stream_to_file(stream, services.upload_path)
      |> handle_save_result
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

fn save_stream_to_file(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(Nil, simplifile.FileError) {
  use _ <- result.try(simplifile.create_file(path))
  yielder.try_fold(stream, Nil, fn(_nothing, chunk) {
    simplifile.append_bits(path, chunk)
  })
}

fn handle_save_result(result: Result(Nil, simplifile.FileError)) -> Response {
  case result {
    Ok(_) -> text_response(status.ok, "File saved successfully")
    Error(_) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
}
```

## Streaming Middleware

### Transform Request Stream

Middleware can transform streaming request bodies. A middleware is a function
that gets the request, the context, the services and the next handler:

#### Uppercase the request stream <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_middleware.gleam#L6-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, Post, Request}
import dream/http/response.{
  type Response, Response, Stream, stream_response, text_response,
}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/yielder

pub fn uppercase_incoming(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let transformed_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(transformed_request, context, services)
    }
    _ -> next(request, context, services)
  }
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  uppercase_bytes(chunk, <<>>)
}

fn uppercase_bytes(remaining: BitArray, uppercased: BitArray) -> BitArray {
  case remaining {
    <<byte, rest:bytes>> ->
      uppercase_bytes(rest, <<uppercased:bits, uppercase_byte(byte)>>)
    _ -> uppercased
  }
}
```

### Transform Response Stream

Middleware can also transform streaming responses:

#### Replace spaces in the response stream <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_middleware.gleam#L52-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn replace_space_outgoing(
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
    Stream(stream) ->
      Response(
        ..response,
        body: Stream(yielder.map(stream, replace_space_chunk)),
      )
    _ -> response
  }
}

// Works on bytes, so a UTF-8 character split across two chunks is kept
fn replace_space_chunk(chunk: BitArray) -> BitArray {
  replace_space_bytes(chunk, <<>>)
}

fn replace_space_bytes(remaining: BitArray, replaced: BitArray) -> BitArray {
  case remaining {
    <<" ":utf8, rest:bytes>> ->
      replace_space_bytes(rest, <<replaced:bits, "_":utf8>>)
    <<byte, rest:bytes>> -> replace_space_bytes(rest, <<replaced:bits, byte>>)
    _ -> replaced
  }
}
```

### Bi-Directional Streaming Example <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_middleware.gleam#L88-L104"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/transform",
    controller: echo_stream,
    middleware: [uppercase_incoming, replace_space_outgoing],
  )
}

// The controller sends the request stream back as the response
pub fn echo_stream(request: Request, _context, _services) -> Response {
  case request.body {
    request.Stream(stream) -> stream_response(status.ok, stream, "text/plain")
    _ -> text_response(status.bad_request, "Expected streaming request")
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

SSE now has its own dedicated module and guide. See the
**[SSE Guide](sse.md)** for a full walkthrough of `upgrade_to_sse`,
event builders, broadcasting, and integration testing.

> **Note:** The old `sse_response` function from `dream/http/response` used
> chunked transfer encoding which stalls after a few events due to TCP
> message contention in the handler process. It has been deprecated in
> favour of `dream/servers/mist/sse.upgrade_to_sse`, which spawns a
> dedicated OTP actor with its own mailbox.

Quick example of the new API:

#### Send a ping event <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_sse.gleam#L6-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/option.{type Option, None}

pub type Message {
  Tick
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: fn(subject, _dependencies) {
      process.send(subject, Tick)
      #(0, None)
    },
    on_message: fn(count, _message, connection, _dependencies) {
      let _ = sse.send_event(connection, sse.event("ping"))
      sse.continue_connection(count + 1)
    },
  )
}
```

## Chunked Transfer Encoding

Dream automatically uses HTTP chunked transfer encoding for streaming responses.

**How it works:**

1. Controller returns `stream_response(...)`
2. Dream sends headers with `Transfer-Encoding: chunked`
3. Each yielder value becomes a chunk
4. Client receives chunks as they're generated
5. When the yielder is done, Dream sends the last chunk, which has zero length
6. Over HTTP/1.1 the server then closes the connection. It does not keep the
   connection open for another request. Over HTTP/2 only that stream ends

**No configuration needed** - it's automatic for streaming responses.

## Best Practices

### 1. Use Appropriate Buffer Sizes <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_chunks.gleam#L6-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/bit_array
import gleam/int
import gleam/yielder.{type Yielder}

// Small chunks: one line per chunk, for a real-time feel
pub fn create_line_stream() -> Yielder(BitArray) {
  yielder.range(1, 1000)
  |> yielder.map(number_to_line)
}

// Larger chunks: 100 lines per chunk, for efficiency
pub fn create_batched_line_stream() -> Yielder(BitArray) {
  create_line_stream()
  |> yielder.sized_chunk(into: 100)
  |> yielder.map(bit_array.concat)
}

fn number_to_line(number: Int) -> BitArray {
  bit_array.from_string(int.to_string(number) <> "\n")
}
```

### 2. Handle Errors Gracefully <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_upload_checks.gleam#L17-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
const max_upload_bytes = 1_000_000

pub type UploadError {
  UploadTooLarge(limit: Int)
}

pub fn upload_stream(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      process_stream_safely(stream)
      |> handle_upload_result
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

fn process_stream_safely(
  stream: yielder.Yielder(BitArray),
) -> Result(String, UploadError) {
  stream
  |> yielder.try_fold(0, add_chunk_size)
  |> result.map(format_bytes_message)
}

fn add_chunk_size(
  total_bytes: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  let new_total = total_bytes + bit_array.byte_size(chunk)
  case new_total > max_upload_bytes {
    True -> Error(UploadTooLarge(limit: max_upload_bytes))
    False -> Ok(new_total)
  }
}

fn format_bytes_message(total_bytes: Int) -> String {
  "Processed " <> int.to_string(total_bytes) <> " bytes"
}

fn handle_upload_result(result: Result(String, UploadError)) -> Response {
  case result {
    Ok(message) -> text_response(status.ok, message)
    Error(UploadTooLarge(limit)) ->
      text_response(
        status.bad_request,
        "Upload is larger than " <> int.to_string(limit) <> " bytes",
      )
  }
}
```

### 3. Use Streaming Routes Explicitly <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_ingress.gleam#L66-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// DON'T: assume every POST route streams. This body arrives buffered.
pub fn create_buffered_upload_router() -> Router(context, services) {
  router()
  |> route(
    method: Post,
    path: "/upload",
    controller: upload_stream,
    middleware: [],
  )
}

// DO: mark streaming routes explicitly. This body is a Yielder(BitArray).
pub fn create_streaming_upload_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload_stream,
    middleware: [],
  )
}
```

### 4. Clean Up Resources <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_saving.gleam#L45-L116"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type UploadError {
  UploadTooLarge
  WriteFailed(simplifile.FileError)
}

pub fn save_upload_with_limit(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.body {
    Stream(stream) -> save_or_clean_up(stream, services)
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn save_or_clean_up(
  stream: yielder.Yielder(BitArray),
  services: Services,
) -> Response {
  case write_limited_stream(stream, services) {
    Ok(_total_bytes) -> text_response(status.created, "Upload saved")
    Error(error) -> {
      // Clean up the partial upload
      let _ = simplifile.delete(services.upload_path)
      create_failure_response(error)
    }
  }
}

fn write_limited_stream(
  stream: yielder.Yielder(BitArray),
  services: Services,
) -> Result(Int, UploadError) {
  use _ <- result.try(
    simplifile.create_file(services.upload_path)
    |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, 0, fn(total_bytes, chunk) {
    write_chunk(services, total_bytes, chunk)
  })
}

fn write_chunk(
  services: Services,
  total_bytes: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  let new_total = total_bytes + bit_array.byte_size(chunk)
  use _ <- result.try(check_upload_size(new_total, services.max_upload_bytes))
  simplifile.append_bits(services.upload_path, chunk)
  |> result.replace(new_total)
  |> result.map_error(WriteFailed)
}

fn check_upload_size(
  total_bytes: Int,
  max_bytes: Int,
) -> Result(Nil, UploadError) {
  case total_bytes > max_bytes {
    True -> Error(UploadTooLarge)
    False -> Ok(Nil)
  }
}

fn create_failure_response(error: UploadError) -> Response {
  case error {
    UploadTooLarge -> text_response(status.bad_request, "Upload is too large")
    WriteFailed(_reason) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
}
```

If the upload is too large, the controller deletes the partial file before it
answers.

## Streaming vs Buffering

### Request Handling

| Feature | Buffered Route | Streaming Route |
|---------|----------------|-----------------|
| Route | `route(...)` | `stream_route(...)` |
| `request.body` | `Text(String)`, or `Bytes(BitArray)` when not UTF-8 | `Stream(Yielder(BitArray))` |
| Memory | Loads full body | Processes chunks |
| Max size | Limited by `max_body_size` | Can be unlimited |
| Use for | Forms, JSON APIs | File uploads, large payloads |

### Response Types <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_types.gleam#L6-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, Request}
import dream/http/response.{
  type Response, type ResponseBody, Bytes, Stream, Text, stream_response,
}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/yielder.{type Yielder}

// Buffered text response: the entire response is in memory
pub fn create_text_body() -> ResponseBody {
  Text("Hello, World!")
}

// Buffered binary response: the entire file is in memory
pub fn create_bytes_body(image_data: BitArray) -> ResponseBody {
  Bytes(image_data)
}

// Streaming response: chunks are made on demand
pub fn create_stream_body(file_chunks: Yielder(BitArray)) -> ResponseBody {
  Stream(file_chunks)
}
```

## Common Patterns

### Pattern 1: CSV Export <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_patterns.gleam#L16-L53"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type User {
  User(id: Int, name: String, email: String)
}

pub type Services {
  Services(list_users: fn() -> Result(List(User), String))
}

pub fn export_users_csv(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  services.list_users()
  |> result.map(yielder.from_list)
  |> result.map(users_to_csv_stream)
  |> result.map(create_csv_stream_response)
  |> result.lazy_unwrap(create_error_response)
}

fn users_to_csv_stream(users: Yielder(User)) -> Yielder(BitArray) {
  users
  |> yielder.map(user_to_csv_row)
  |> yielder.prepend("id,name,email\n")
  |> yielder.map(bit_array.from_string)
}

fn create_csv_stream_response(stream: Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}

fn create_error_response() -> Response {
  text_response(status.internal_server_error, "Could not load users")
}

fn user_to_csv_row(user: User) -> String {
  int.to_string(user.id) <> "," <> user.name <> "," <> user.email <> "\n"
}
```

### Pattern 2: Progress Updates <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_sse.gleam#L32-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ProgressMessage {
  ProgressUpdate(percent: Int)
}

pub fn long_running_task(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: start_progress,
    on_message: send_progress,
  )
}

fn start_progress(
  subject: Subject(ProgressMessage),
  _dependencies: Nil,
) -> #(Subject(ProgressMessage), Option(Selector(ProgressMessage))) {
  process.send(subject, ProgressUpdate(0))
  #(subject, None)
}

fn send_progress(
  subject: Subject(ProgressMessage),
  message: ProgressMessage,
  connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Subject(ProgressMessage), ProgressMessage) {
  let _ = sse.send_event(connection, progress_to_event(message.percent))
  continue_until_done(subject, message.percent)
}

fn continue_until_done(
  subject: Subject(ProgressMessage),
  percent: Int,
) -> sse.Action(Subject(ProgressMessage), ProgressMessage) {
  case percent >= 100 {
    True -> sse.stop_connection()
    False -> {
      process.send(subject, ProgressUpdate(percent + 25))
      sse.continue_connection(subject)
    }
  }
}

fn progress_to_event(percent: Int) -> sse.Event {
  sse.event("{\"progress\": " <> int.to_string(percent) <> "}")
}
```

In a real app, a worker process sends the `ProgressUpdate` messages. Here the
handler sends them to itself, so the example stays small. After the event for
100%, `sse.stop_connection()` closes the stream.

### Pattern 3: File Upload with Validation <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_upload_checks.gleam#L66-L153"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ImageError {
  EmptyUpload
  InvalidFileType
  SaveFailed(simplifile.FileError)
}

pub type Services {
  Services(upload_path: String)
}

pub fn upload_image(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.body {
    Stream(stream) ->
      validate_and_save_image(stream, services.upload_path)
      |> map_validation_result_to_response
    _ -> text_response(status.bad_request, "Expected file upload")
  }
}

fn validate_and_save_image(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(String, ImageError) {
  use full_stream <- result.try(validate_image_header(yielder.step(stream)))
  save_to_storage(full_stream, path)
}

fn validate_image_header(
  step: yielder.Step(BitArray, yielder.Yielder(BitArray)),
) -> Result(yielder.Yielder(BitArray), ImageError) {
  case step {
    yielder.Next(first_chunk, rest) -> {
      use _ <- result.try(check_is_valid_image(first_chunk))
      Ok(yielder.prepend(rest, first_chunk))
    }
    yielder.Done -> Error(EmptyUpload)
  }
}

fn check_is_valid_image(chunk: BitArray) -> Result(Nil, ImageError) {
  case is_valid_image(chunk) {
    True -> Ok(Nil)
    False -> Error(InvalidFileType)
  }
}

fn is_valid_image(chunk: BitArray) -> Bool {
  case chunk {
    // PNG
    <<0x89, 0x50, 0x4E, 0x47, _rest:bits>> -> True
    // JPEG
    <<0xFF, 0xD8, 0xFF, _rest:bits>> -> True
    _ -> False
  }
}

fn save_to_storage(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(String, ImageError) {
  use _ <- result.try(
    simplifile.write_bits(path, <<>>) |> result.map_error(SaveFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, chunk) {
    simplifile.append_bits(path, chunk)
  })
  |> result.map_error(SaveFailed)
  |> result.replace(path)
}

fn map_validation_result_to_response(
  result: Result(String, ImageError),
) -> Response {
  case result {
    Ok(path) ->
      json_response(
        status.created,
        json.to_string(json.object([#("path", json.string(path))])),
      )
    Error(InvalidFileType) ->
      text_response(status.unprocessable_content, "Invalid image format")
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

#### Buffered response <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_patterns.gleam#L55-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// BAD for large exports: the whole CSV is one string in memory
pub fn export_users_buffered(users: List(User)) -> Response {
  let csv =
    string.concat(["id,name,email\n", ..list.map(users, user_to_csv_row)])
  text_response(status.ok, csv)
}
```

#### Streaming response <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_patterns.gleam#L62-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// GOOD for large exports: each row is made when the client reads it
pub fn export_users_streamed(users: Yielder(User)) -> Response {
  let csv_stream = users_to_csv_stream(users)
  stream_response(status.ok, csv_stream, "text/csv")
}
```

### Backpressure

Yielders provide natural backpressure:
- Client stops reading → Server stops generating
- No unbounded buffering
- Memory stays constant regardless of data size

### Chunk Sizing <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_chunks.gleam#L27-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Small chunks: more responsive, more overhead
pub fn create_tiny_chunks(data: BitArray) -> Yielder(BitArray) {
  yielder.repeat(data)
  |> yielder.take(1000)
}

// Large chunks: less responsive, more efficient
pub fn group_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.sized_chunk(into: 64)
  |> yielder.map(bit_array.concat)
}

// Chunks that follow the data: one chunk per database row
pub fn create_row_chunks(rows: List(String)) -> Yielder(BitArray) {
  yielder.from_list(rows)
  |> yielder.map(bit_array.from_string)
}
```

## Testing Streaming

### Unit Tests <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_unit_test.gleam#L6-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/response.{Stream, stream_response}
import dream/http/status
import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/yielder

pub fn tests() -> UnitTest {
  describe("streaming", [
    it("generates expected chunks", fn() {
      // Arrange
      let stream =
        yielder.range(1, 3)
        |> yielder.map(int_to_byte)

      // Act
      let response =
        stream_response(status.ok, stream, "application/octet-stream")

      // Assert
      case response.body {
        Stream(chunks) ->
          yielder.to_list(chunks)
          |> list.length()
          |> should()
          |> equal(3)
          |> or_fail_with("Should have 3 chunks")
        _ -> fail_with("Expected Stream body")
      }
    }),
  ])
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
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

### ❌ Don't Consume Stream Twice <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_pitfalls.gleam#L14-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// BAD: the stream is read twice
pub fn download_with_line_count(
  _request: Request,
  _context,
  _services,
) -> Response {
  let stream = yielder.range(1, 100) |> yielder.map(number_to_line)
  let line_count = yielder.length(stream)
  let first_line = "Lines: " <> int.to_string(line_count) <> "\n"
  let body = yielder.prepend(stream, <<first_line:utf8>>)
  stream_response(status.ok, body, "text/plain")
}

fn number_to_line(number: Int) -> BitArray {
  let line = "Line " <> int.to_string(number) <> "\n"
  <<line:utf8>>
}
```

`yielder.length` reads every chunk to count them. Then the client reads the
stream again, so the work runs twice. A request body stream (`Stream` in `request.body`)
is worse: it reads from the socket, so after the first read the bytes are gone
and a second read gets nothing.

### ❌ Don't Mix Streaming and Buffering <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_pitfalls.gleam#L32-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// BAD: defeats the purpose of streaming
pub fn send_buffered(stream: Yielder(BitArray)) -> Response {
  let all_chunks = yielder.to_list(stream)
  stream_response(status.ok, yielder.from_list(all_chunks), "text/plain")
}

// GOOD: keep it lazy
pub fn send_lazy(stream: Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/plain")
}
```

### ❌ Don't Forget Error Handling <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_pitfalls.gleam#L43-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// BAD: a buffered body becomes an empty upload
pub fn upload_without_check(request: Request, _context, _services) -> Response {
  let stream = case request.body {
    Stream(stream) -> stream
    _ -> yielder.empty()
  }
  save_stream(stream)
}

// GOOD: reject a body that is not a stream
pub fn upload_with_check(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) -> save_stream(stream)
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn save_stream(stream: Yielder(BitArray)) -> Response {
  let total_bytes = yielder.fold(stream, 0, add_chunk_size)
  text_response(status.ok, "Saved " <> int.to_string(total_bytes) <> " bytes")
}

fn add_chunk_size(total_bytes: Int, chunk: BitArray) -> Int {
  total_bytes + bit_array.byte_size(chunk)
}
```

The bad controller treats a body that is not a `Stream` as an empty upload.
When the route is registered with `route` instead of `stream_route`, the body
arrives as `Text` or `Bytes`, the client gets `200 Saved 0 bytes`, and nobody
learns that the data was lost.

## API Reference

### Response Builders <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_types.gleam#L30-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Stream with a custom content type
pub fn create_csv_download(csv_rows: Yielder(BitArray)) -> Response {
  stream_response(status.ok, csv_rows, "text/csv")
}
```

`sse_response` is deprecated. For Server-Sent Events, use
`dream/servers/mist/sse.upgrade_to_sse`. See the [SSE Guide](sse.md).

### Router Functions <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_ingress.gleam#L88-L97"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// stream_route works with any HTTP method
pub fn create_file_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Put,
    path: "/files/:name",
    controller: upload_stream,
    middleware: [],
  )
}
```

### Request Fields <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_types.gleam#L35-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// A streaming route gives the controller a request like this one
pub fn create_streaming_request(
  request: Request,
  chunks: Yielder(BitArray),
) -> Request {
  // The response module also has a Stream constructor, so name the
  // request one by its module
  Request(..request, body: request.Stream(chunks))
}
```

### Response Body Types <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/streaming_guide_types.gleam#L45-L54"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn describe_body(body: ResponseBody) -> String {
  case body {
    // Buffered text response
    Text(text) -> "Text: " <> text
    // Buffered binary response
    Bytes(bytes) -> "Bytes: " <> int.to_string(bit_array.byte_size(bytes))
    // Streaming response
    Stream(_chunks) -> "Stream"
  }
}
```

## See Also

- [Multiple Formats Guide](multiple-formats.md) - Different response formats
- [File Uploads Guide](file-uploads.md) - Multipart form handling
- [Streaming Example](../../examples/streaming/) - HTTP client streaming
- [Streaming Capabilities Example](../../examples/streaming_capabilities/) - Advanced streaming
- [Multi-Format Example](../../examples/multi_format/) - CSV streaming with database
