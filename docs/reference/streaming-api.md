# Streaming API Reference

Complete API reference for Dream's streaming functionality.

## Types

Each example below builds or matches a type with every field or variant
named, so it shows the whole type.

### Request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_types.gleam#L17-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_upload_request(chunks: Yielder(BitArray)) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/upload",
    query: "",
    params: [],
    host: None,
    port: None,
    remote_address: None,
    // A streaming route gets the request body as a stream of chunks.
    body: request.Stream(chunks),
    headers: [],
    cookies: [],
    content_type: Some("application/octet-stream"),
    content_length: None,
  )
}
```

**Fields:**
- `body`: Request body as a `RequestBody` (see below)

**Usage:**
- Regular routes: `body` is `Text(String)` for a UTF-8 body, or
  `Bytes(BitArray)` with the exact bytes for any other body. An empty body
  is `Text("")`.
- Streaming routes: `body` is `Stream(Yielder(BitArray))`

### RequestBody <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_types.gleam#L58-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn describe_request_body(body: RequestBody) -> String {
  case body {
    // A normal route, body is valid UTF-8: JSON, form data, plain text
    request.Text(_text) -> "buffered text"
    // A normal route, body is not valid UTF-8: images, PDFs
    request.Bytes(_bytes) -> "buffered bytes"
    // A stream_route: uploads read chunk by chunk
    request.Stream(_chunks) -> "stream"
  }
}
```

`RequestBody` and `ResponseBody` use the same constructor names, so a
module that imports both qualifies one of them, as in `request.Text`.
`body_as_string` gives the text of any request body, and `Error(Nil)`
when the bytes are not valid UTF-8.

### ResponseBody <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_types.gleam#L37-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn describe_body(body: ResponseBody) -> String {
  case body {
    // Buffered text: JSON, HTML, plain text
    Text(_text) -> "buffered text"
    // Buffered binary: images, PDFs
    Bytes(_bytes) -> "buffered bytes"
    // Streaming: large files, real-time data, CSV exports
    Stream(_chunks) -> "stream"
  }
}
```

**Usage:**
- `Text(...)`: Most responses (JSON, HTML, plain text)
- `Bytes(...)`: Binary files (images, PDFs)
- `Stream(...)`: Large files, real-time data, CSV exports

### Response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_types.gleam#L48-L56"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_csv_export_response(rows: Yielder(BitArray)) -> Response {
  Response(
    status: 200,
    body: Stream(rows),
    headers: [Header("Content-Type", "text/csv")],
    cookies: [],
    content_type: Some("text/csv"),
  )
}
```

## Response Builders

### stream_response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const stream_response: fn(Int, Yielder(BitArray), String) -> Response = response.stream_response
```

Create a streaming response. The arguments are the status, the stream and
the content type.

**Parameters:**
- `status`: HTTP status code (use `status.ok`, `status.created`, etc.)
- `stream`: Yielder that generates BitArray chunks
- `content_type`: MIME type (e.g., `"text/csv"`, `"application/octet-stream"`)

**Returns:** Response with Stream body and Transfer-Encoding: chunked

#### Stream a download <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_responses.gleam#L15-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn download(_request: Request, _context, _services) -> Response {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(int_to_byte)

  stream_response(status.ok, stream, "application/octet-stream")
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
}
```

### sse_response (deprecated)

> **Deprecated.** This function uses chunked transfer encoding which stalls
> after a few events. Use `upgrade_to_sse` from `dream/servers/mist/sse`
> instead. See the [SSE guide](../guides/sse.md).

#### sse_response signature <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const sse_response: fn(Int, Yielder(BitArray), String) -> Response = response.sse_response
```

### Server-Sent Events (SSE)

For full SSE documentation, see the [SSE guide](../guides/sse.md).

#### upgrade_to_sse <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L21-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const upgrade_to_sse: fn(
  Request,
  deps,
  fn(Subject(message), deps) -> #(state, Option(Selector(message))),
  fn(state, message, SSEConnection, deps) -> Action(state, message),
) -> Response = sse.upgrade_to_sse
```

Upgrade an HTTP request to a Server-Sent Events connection backed by a
dedicated OTP actor. Import it from `dream/servers/mist/sse`.

**Parameters:**
- `request`: The incoming HTTP request
- `dependencies`: Application dependencies passed to all handlers
- `on_init`: Called once when the actor starts. Receives the actor's
  `Subject(message)` for external message sending. Returns initial state
  and optional selector.
- `on_message`: Called for each message. Returns the next action.

#### Send tick events <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_sse.gleam#L13-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Message {
  Tick
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: fn(subject, _dependencies) {
      process.send(subject, Tick)
      process.send(subject, Tick)
      #(0, None)
    },
    on_message: fn(count, _message, connection, _dependencies) {
      send_tick(connection, count)
    },
  )
}

fn send_tick(
  connection: sse.SSEConnection,
  count: Int,
) -> sse.Action(Int, Message) {
  case sse.send_event(connection, create_tick_event(count)) {
    Ok(Nil) -> sse.continue_connection(count + 1)
    Error(Nil) -> sse.stop_connection()
  }
}
```

`on_init` puts two `Tick` messages in the actor's mailbox. Each `Tick` sends
one event and keeps the connection open. If an event cannot be sent because
the client has gone, the actor stops.

#### send_event <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const send_event: fn(SSEConnection, Event) -> Result(Nil, Nil) = sse.send_event
```

Send an SSE event to the client.

#### event / event_name / event_id / event_retry <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L30-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const event: fn(String) -> Event = sse.event

pub const event_name: fn(Event, String) -> Event = sse.event_name

pub const event_id: fn(Event, String) -> Event = sse.event_id

pub const event_retry: fn(Event, Int) -> Event = sse.event_retry
```

Build structured SSE events. Only `event(data)` is required.

#### Build a tick event <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_sse.gleam#L42-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_tick_event(count: Int) -> sse.Event {
  let count_text = int.to_string(count)
  sse.event("{\"count\": " <> count_text <> "}")
  |> sse.event_name("tick")
  |> sse.event_id(count_text)
  |> sse.event_retry(5000)
}
```

#### continue_connection / stop_connection <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L38-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const continue_connection: fn(state) -> Action(state, message) = sse.continue_connection

pub const continue_connection_with_selector: fn(state, Selector(message)) ->
  Action(state, message) = sse.continue_connection_with_selector

pub const stop_connection: fn() -> Action(state, message) = sse.stop_connection
```

Control the SSE actor loop. `continue_connection` keeps the actor alive,
`stop_connection` shuts it down.

## Router Functions

### stream_route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L45-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub const stream_route: fn(
  Router(context, services),
  Method,
  String,
  fn(Request, context, services) -> Response,
  List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) = router.stream_route

```

Add a streaming route to the router for any HTTP method. The arguments are
the router, then `method:`, `path:`, `controller:` and `middleware:`.

Registers a route that receives the request body as a stream (Yielder(BitArray))
instead of a buffered `Text` or `Bytes` body. Use for large file uploads (> 10MB), proxying
external APIs, or any case where you want to process the request body in chunks.

**Parameters:**
- `method`: HTTP method (Post, Put, Patch, etc.)
- `path`: URL path (can include parameters like `"/upload/:id"`)
- `controller`: Controller function to handle the request
- `middleware`: List of middleware functions to run (can transform stream)

**Behavior:**
- `request.body` is `Stream(Yielder(BitArray))`
- Body is not buffered - processed as chunks arrive
- Memory usage stays constant regardless of upload size

#### Add streaming routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_routing.gleam#L17-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload,
    middleware: [],
  )
  |> stream_route(
    method: Put,
    path: "/files/:id",
    controller: replace_file,
    middleware: [require_api_key],
  )
}
```

`upload` and `replace_file` are controllers, and `require_api_key` is a
middleware function in the same module.

### route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L57-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  Router(context, services),
  Method,
  String,
  fn(Request, context, services) -> Response,
  List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) = router.route

pub const max_body_size: fn(
```

Add a regular buffered route to the router. It takes the same arguments as
`stream_route`.

For streaming routes, use `stream_route()` instead.

## Yielder Operations

Common operations on streaming data:

### Transform Chunks <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_yielder.gleam#L8-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn uppercase_stream(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.map(uppercase_chunk)
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

### Filter Chunks <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_yielder.gleam#L34-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn remove_empty_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.filter(is_non_empty_chunk)
}

fn is_non_empty_chunk(chunk: BitArray) -> Bool {
  bit_array.byte_size(chunk) > 0
}
```

### Fold/Reduce <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_yielder.gleam#L43-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn count_total_bytes(stream: Yielder(BitArray)) -> Int {
  stream
  |> yielder.fold(0, add_chunk_size)
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}
```

### Take Limited <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_yielder.gleam#L52-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn take_first_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.take(100)
}
```

### Chain Streams <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_yielder.gleam#L57-L68"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_csv_stream(names: List(String)) -> Yielder(BitArray) {
  let header = yielder.single(<<"name\n":utf8>>)
  let rows =
    yielder.from_list(names)
    |> yielder.map(to_csv_row)

  yielder.append(header, rows)
}

fn to_csv_row(name: String) -> BitArray {
  bit_array.from_string(name <> "\n")
}
```

## Server Configuration

### max_body_size <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_signatures.gleam#L69-L72"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  Int,
) -> Dream(Builder(Connection, ResponseData), context, services) = server.max_body_size

```

Set maximum buffered body size in bytes. Import it from
`dream/servers/mist/server`.

**Default:** 10MB (10_000_000 bytes)

**For streaming routes:** This limit doesn't apply (streams can be unlimited)

#### Raise the body size limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_routing.gleam#L130-L134"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_large_payload_server() {
  server.new()
  // 100MB for large JSON payloads
  |> server.max_body_size(100_000_000)
}
```

Add a router to this server and call `server.listen` to start it.

## Middleware with Streaming

A middleware is a function that takes the request, the context, the services
and the next handler. Give it to a route in the `middleware:` list.

### Request Stream Transformation <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_routing.gleam#L71-L107"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn uppercase_incoming(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let new_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(new_request, context, services)
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

// Only the ASCII letters a to z change. Every byte of a multi-byte UTF-8
// character is 128 or more, so a character split across two chunks is kept.
fn uppercase_byte(byte: Int) -> Int {
  case byte >= 97 && byte <= 122 {
    True -> byte - 32
    False -> byte
  }
}
```

### Response Stream Transformation <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_routing.gleam#L109-L128"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn end_outgoing_chunks_with_newline(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)

  case response.body {
    Stream(stream) -> {
      let newline_stream = yielder.map(stream, append_newline)
      Response(..response, body: Stream(newline_stream))
    }
    _ -> response
  }
}

fn append_newline(chunk: BitArray) -> BitArray {
  bit_array.append(chunk, <<"\n":utf8>>)
}
```

## Performance Notes

### Chunk Sizing

- **Small chunks (< 1KB)**: More responsive, higher overhead
- **Medium chunks (4-64KB)**: Good balance (recommended)
- **Large chunks (> 1MB)**: Less overhead, less responsive

**Recommendation:** Use 64KB chunks for most cases.

### Backpressure

Yielders provide natural backpressure:
- Client reads slowly → Server generates slowly
- Client stops reading → Server stops generating
- No unbounded buffering
- Memory stays constant

### Memory Usage

#### Buffered response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_responses.gleam#L27-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_buffered_report(line_count: Int) -> Response {
  // Builds the whole report in memory before the response is sent
  let report = string.repeat("report line\n", line_count)
  text_response(status.ok, report)
}
```

Don't do this for a large report. The whole report is in memory before the
response is sent, so peak memory grows with the size of the report.

#### Streaming response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_responses.gleam#L33-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_streamed_report(line_count: Int) -> Response {
  // Builds each line only when the client is ready for it
  let stream =
    yielder.repeat(<<"report line\n":utf8>>)
    |> yielder.take(line_count)
  stream_response(status.ok, stream, "text/plain")
}
```

Peak memory stays near the size of one chunk, whatever the size of the report.

## Error Handling

### Handle Stream Errors <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_api_responses.gleam#L41-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type UploadError {
  InvalidChunk
}

pub fn upload(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) -> respond_to_upload(stream)
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn respond_to_upload(stream: Yielder(BitArray)) -> Response {
  case process_stream_safely(stream) {
    Ok(message) -> text_response(status.ok, message)
    Error(InvalidChunk) ->
      text_response(status.unprocessable_content, "Upload must be UTF-8 text")
  }
}

fn process_stream_safely(
  stream: Yielder(BitArray),
) -> Result(String, UploadError) {
  stream
  |> yielder.try_fold(0, validate_and_add_chunk_size)
  |> result.map(format_total_bytes_message)
}

fn validate_and_add_chunk_size(
  total: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  case is_valid_chunk(chunk) {
    True -> Ok(total + bit_array.byte_size(chunk))
    False -> Error(InvalidChunk)
  }
}

fn is_valid_chunk(chunk: BitArray) -> Bool {
  result.is_ok(bit_array.to_string(chunk))
}

fn format_total_bytes_message(total: Int) -> String {
  "Processed " <> int.to_string(total) <> " bytes"
}
```

## See Also

- [Streaming Guide](../guides/streaming.md) - Complete streaming guide
- [Multiple Formats Guide](../guides/multiple-formats.md) - CSV streaming
- [File Uploads Guide](../guides/file-uploads.md) - Multipart forms
- [Streaming Example](../../examples/streaming_capabilities/) - Working code
