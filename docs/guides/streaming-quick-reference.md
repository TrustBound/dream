# Streaming Quick Reference

Quick copy-paste patterns for common streaming tasks.

## Upload File (Ingress) <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_upload.gleam#L6-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Post, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/result
import gleam/yielder

// Router
pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload_file,
    middleware: [],
  )
}

// Controller
pub fn upload_file(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      yielder.try_fold(stream, 0, add_chunk_size)
      |> respond_with_total
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn respond_with_total(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes",
      )
    // The connection broke before the client sent the whole body
    Error(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}

fn add_chunk_size(
  total_bytes: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  total_bytes + bit_array.byte_size(chunk)
}
```

## Download/Export CSV (Egress) <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_csv.gleam#L6-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/float
import gleam/int
import gleam/yielder

pub type Product {
  Product(id: Int, name: String, price: Float)
}

pub type Services {
  Services(list_products: fn() -> Result(List(Product), String))
}

pub fn export_csv(_request: Request, _context, services: Services) -> Response {
  case services.list_products() {
    Ok(products) -> {
      let csv_stream = products_to_csv_stream(products)
      stream_response(status.ok, csv_stream, "text/csv")
    }
    Error(_reason) ->
      text_response(status.internal_server_error, "Could not load products")
  }
}

fn products_to_csv_stream(
  products: List(Product),
) -> yielder.Yielder(BitArray) {
  yielder.from_list(products)
  |> yielder.map(product_to_csv_row)
  |> yielder.prepend("id,name,price\n")
  |> yielder.map(bit_array.from_string)
}

fn product_to_csv_row(product: Product) -> String {
  int.to_string(product.id)
  <> ","
  <> product.name
  <> ","
  <> float.to_string(product.price)
  <> "\n"
}
```

## Server-Sent Events <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_sse.gleam#L6-L47"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None}

pub type Services {
  Services(events: List(String))
}

pub type EventMessage {
  Publish(data: String)
}

pub fn events(request: Request, _context, services: Services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: services.events,
    on_init: publish_events,
    on_message: send_event,
  )
}

fn publish_events(
  subject: Subject(EventMessage),
  events: List(String),
) -> #(Nil, Option(Selector(EventMessage))) {
  list.each(events, fn(data) { process.send(subject, Publish(data)) })
  #(Nil, None)
}

fn send_event(
  state: Nil,
  message: EventMessage,
  connection: sse.SSEConnection,
  _events: List(String),
) -> sse.Action(Nil, EventMessage) {
  let _ = sse.send_event(connection, sse.event(message.data))
  sse.continue_connection(state)
}
```

Here `Services.events` stands in for a pub/sub feed. `on_init` sends each event
to the SSE actor, and `on_message` writes it to the client.

## Transform Incoming Stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_middleware.gleam#L6-L54"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Request}
import dream/http/response.{type Response, Response, Stream}
import gleam/result
import gleam/yielder

pub fn uppercase_middleware(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_item)
      let new_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(new_request, context, services)
    }
    _ -> next(request, context, services)
  }
}

// An Error item stays as it is, so the controller still sees the failure
fn uppercase_item(
  item: Result(BitArray, BodyReadError),
) -> Result(BitArray, BodyReadError) {
  result.map(item, uppercase_chunk)
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

// Only the ASCII letters a to z change. Every byte of a multi-byte UTF-8
// character is 128 or more, so a character split across two chunks is kept.
fn uppercase_byte(byte: Int) -> Int {
  case byte >= 97 && byte <= 122 {
    True -> byte - 32
    False -> byte
  }
}
```

## Transform Outgoing Stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_middleware.gleam#L56-L92"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn line_endings_middleware(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)

  case response.body {
    Stream(stream) -> {
      let converted_stream =
        stream
        |> yielder.map(convert_line_endings)

      Response(..response, body: Stream(converted_stream))
    }
    _ -> response
  }
}

// Works on bytes, so a UTF-8 character split across two chunks is kept
fn convert_line_endings(chunk: BitArray) -> BitArray {
  convert_line_ending_bytes(chunk, <<>>)
}

fn convert_line_ending_bytes(
  remaining: BitArray,
  converted: BitArray,
) -> BitArray {
  case remaining {
    <<"\n":utf8, rest:bytes>> ->
      convert_line_ending_bytes(rest, <<converted:bits, "\r\n":utf8>>)
    <<byte, rest:bytes>> ->
      convert_line_ending_bytes(rest, <<converted:bits, byte>>)
    _ -> converted
  }
}
```

## Proxy Stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_patterns.gleam#L18-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn proxy(_request: Request, _context, _services) -> Response {
  // Simulate proxying from external API
  let stream =
    yielder.from_list(["Chunk 1\n", "Chunk 2\n", "Chunk 3\n"])
    |> yielder.map(bit_array.from_string)

  stream_response(status.ok, stream, "text/plain")
}
```

## Save Upload to File <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_files.gleam#L6-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String)
}

pub type UploadError {
  EmptyUpload
  InvalidFileType
  // The connection broke before the client sent the whole body
  UploadBroke(BodyReadError)
  SaveFailed(simplifile.FileError)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) -> save_stream_to_disk(stream, services.upload_path)
    _ -> text_response(status.bad_request, "Expected file upload")
  }
}

fn save_stream_to_disk(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Response {
  case write_stream_to_file(stream, file_path) {
    Ok(Nil) -> text_response(status.ok, "File saved: " <> file_path)
    Error(UploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
    Error(_reason) -> text_response(status.internal_server_error, "Save failed")
  }
}

// Writes each chunk. On an error, deletes the partial file.
fn write_stream_to_file(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.write_bits(file_path, <<>>) |> result.map_error(SaveFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, item) {
    append_item(file_path, item)
  })
  |> result.try_recover(delete_partial_file(file_path, _))
}

fn append_item(
  file_path: String,
  item: Result(BitArray, BodyReadError),
) -> Result(Nil, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
  simplifile.append_bits(file_path, chunk) |> result.map_error(SaveFailed)
}

fn delete_partial_file(
  file_path: String,
  error: UploadError,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.delete(file_path) |> result.map_error(SaveFailed),
  )
  Error(error)
}
```

## Validate Upload (First Chunk) <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_files.gleam#L76-L137"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn upload_image(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.body {
    Stream(stream) ->
      validate_and_save(stream, services.upload_path)
      |> create_image_response
    _ -> text_response(status.bad_request, "Expected image upload")
  }
}

fn validate_and_save(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  // Check the first chunk for magic bytes
  case yielder.step(stream) {
    yielder.Next(Ok(first_chunk), rest) ->
      save_if_image(first_chunk, rest, file_path)
    yielder.Next(Error(read_error), _rest) -> Error(UploadBroke(read_error))
    yielder.Done -> Error(EmptyUpload)
  }
}

fn save_if_image(
  first_chunk: BitArray,
  rest: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  case is_valid_image_header(first_chunk) {
    // Put the first chunk back in front of the rest of the stream
    True ->
      yielder.prepend(rest, Ok(first_chunk))
      |> write_stream_to_file(file_path)
    False -> Error(InvalidFileType)
  }
}

fn is_valid_image_header(chunk: BitArray) -> Bool {
  case chunk {
    // PNG
    <<0x89, 0x50, 0x4E, 0x47, _rest:bits>> -> True
    // JPEG
    <<0xFF, 0xD8, 0xFF, _rest:bits>> -> True
    _ -> False
  }
}

fn create_image_response(result: Result(Nil, UploadError)) -> Response {
  case result {
    Ok(Nil) -> text_response(status.created, "Image saved")
    Error(InvalidFileType) ->
      text_response(status.unprocessable_content, "Not an image")
    Error(EmptyUpload) -> text_response(status.bad_request, "Empty upload")
    Error(UploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
    Error(SaveFailed(_reason)) ->
      text_response(status.internal_server_error, "Upload failed")
  }
}
```

## Server Configuration <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_server.gleam#L6-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, type Router, route}
import dream/servers/mist/server.{bind, listen, max_body_size}

pub fn main() {
  create_server()
  |> listen(3000)
}

pub fn create_server() {
  server.new()
  |> server.router(create_router())
  // 100MB for buffered routes (default is 10MB)
  |> max_body_size(100_000_000)
  |> bind("localhost")
}

fn create_router() -> Router(EmptyContext, EmptyServices) {
  router.router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello")
}
```

## Common Patterns

### Pattern: Large CSV Export <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_patterns.gleam#L27-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type User {
  User(id: Int, name: String, email: String)
}

pub type Services {
  Services(list_users: fn() -> Result(List(User), String))
}

pub fn export_users(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  case services.list_users() {
    Ok(users) -> {
      let header = yielder.single(<<"id,name,email\n":utf8>>)
      let rows =
        yielder.from_list(users)
        |> yielder.map(user_to_csv_row)
        |> yielder.map(bit_array.from_string)

      let csv_stream = yielder.append(header, rows)

      stream_response(status.ok, csv_stream, "text/csv")
    }
    Error(_reason) ->
      text_response(status.internal_server_error, "Could not load users")
  }
}

fn user_to_csv_row(user: User) -> String {
  int.to_string(user.id) <> "," <> user.name <> "," <> user.email <> "\n"
}
```

### Pattern: Progress Updates <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_sse.gleam#L49-L88"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ProgressMessage {
  ProgressUpdate(percent: Int)
}

pub fn long_task(request: Request, _context, _services) -> Response {
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
  let _ = sse.send_event(connection, percent_to_event(message.percent))
  case message.percent >= 100 {
    True -> sse.stop_connection()
    False -> {
      process.send(subject, ProgressUpdate(message.percent + 25))
      sse.continue_connection(subject)
    }
  }
}

fn percent_to_event(percent: Int) -> sse.Event {
  sse.event("{\"progress\": " <> int.to_string(percent) <> "}")
}
```

### Pattern: Conditional Streaming <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_patterns.gleam#L61-L91"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn get_users(request: Request, context, services: Services) -> Response {
  let format = get_query_param(request.query, "format")

  case format {
    Some("csv") -> export_users(request, context, services)
    Some("json") -> export_users_json(services)
    _ -> text_response(status.bad_request, "Use ?format=csv or ?format=json")
  }
}

fn export_users_json(services: Services) -> Response {
  services.list_users()
  |> result.map(users_to_json)
  |> result.map(json_response(status.ok, _))
  |> result.lazy_unwrap(fn() {
    text_response(status.internal_server_error, "Could not load users")
  })
}

fn users_to_json(users: List(User)) -> String {
  json.array(users, user_to_json)
  |> json.to_string()
}

fn user_to_json(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}
```

## Testing Streaming <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_quick_unit_test.gleam#L6-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/response.{Stream, stream_response}
import dream/http/status
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/yielder

pub fn tests() -> TestSuite {
  describe("streaming", [
    it("yields expected chunks", fn() {
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
          |> be_equal(3)
          |> or_fail_with("Should have 3 chunks")
        _ -> Ok(fail_with("Expected Stream body"))
      }
    }),
  ])
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
}
```

## See Also

- [Streaming Guide](https://github.com/TrustBound/dream/blob/main/docs/guides/streaming.md) - Complete guide
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/streaming-api.md) - Full API docs
- [WebSockets Guide](https://github.com/TrustBound/dream/blob/main/docs/guides/websockets.md) - Real-time, bi-directional connections
- [Examples](https://github.com/TrustBound/dream/tree/main/examples/streaming_capabilities) - Working code

