# Streaming API Reference

Complete API reference for Dream's streaming functionality.

## Types

### Request

```gleam
pub type Request {
  Request(
    method: Method,
    protocol: Protocol,
    version: Version,
    path: String,
    query: String,
    params: List(#(String, String)),
    host: Option(String),
    port: Option(Int),
    remote_address: Option(String),
    body: String,                           // Buffered body (empty for streaming routes)
    stream: Option(Yielder(BitArray)),      // Streaming body (Some for streaming routes)
    headers: List(Header),
    cookies: List(Cookie),
    content_type: Option(String),
    content_length: Option(Int),
  )
}
```

**Fields:**
- `body`: Full request body as String (for buffered routes)
- `stream`: Request body as Yielder(BitArray) (for streaming routes)

**Usage:**
- Regular routes: `body` contains data, `stream` is `None`
- Streaming routes: `body` is `""`, `stream` is `Some(Yielder(BitArray))`

### ResponseBody

```gleam
pub type ResponseBody {
  Text(String)                      // Buffered text response
  Bytes(BitArray)                   // Buffered binary response
  Stream(Yielder(BitArray))         // Streaming response
}
```

**Usage:**
- `Text(...)`: Most responses (JSON, HTML, plain text)
- `Bytes(...)`: Binary files (images, PDFs)
- `Stream(...)`: Large files, real-time data, CSV exports

### Response

```gleam
pub type Response {
  Response(
    status: Int,
    body: ResponseBody,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: Option(String),
  )
}
```

## Response Builders

### stream_response

```gleam
pub fn stream_response(
  status: Int,
  stream: Yielder(BitArray),
  content_type: String,
) -> Response
```

Create a streaming response.

**Parameters:**
- `status`: HTTP status code (use `status.ok`, `status.created`, etc.)
- `stream`: Yielder that generates BitArray chunks
- `content_type`: MIME type (e.g., `"text/csv"`, `"application/octet-stream"`)

**Returns:** Response with Stream body and Transfer-Encoding: chunked

**Example:**
```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder

pub fn download(request, context, services) {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(int_to_byte)
  
  stream_response(status.ok, stream, "application/octet-stream")
}

fn int_to_byte(n: Int) -> BitArray {
  <<n:8>>
}
```

### sse_response (deprecated)

> **Deprecated.** This function uses chunked transfer encoding which stalls
> after a few events. Use `upgrade_to_sse` from `dream/servers/mist/sse`
> instead. See the [SSE guide](../guides/sse.md).

```gleam
pub fn sse_response(
  status: Int,
  stream: Yielder(BitArray),
  content_type: String,
) -> Response
```

### Server-Sent Events (SSE)

For full SSE documentation, see the [SSE guide](../guides/sse.md).

#### upgrade_to_sse

```gleam
import dream/servers/mist/sse

pub fn upgrade_to_sse(
  request: Request,
  dependencies deps: deps,
  on_init: fn(Subject(message), deps) -> #(state, Option(Selector(message))),
  on_message: fn(state, message, SSEConnection, deps) -> Action(state, message),
) -> Response
```

Upgrade an HTTP request to a Server-Sent Events connection backed by a
dedicated OTP actor.

**Parameters:**
- `request`: The incoming HTTP request
- `dependencies`: Application dependencies passed to all handlers
- `on_init`: Called once when the actor starts. Receives the actor's
  `Subject(message)` for external message sending. Returns initial state
  and optional selector.
- `on_message`: Called for each message. Returns the next action.

**Example:**
```gleam
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/option.{None}

pub fn handle_events(request, _context, _services) {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: fn(subject, _deps) {
      process.send(subject, Tick)
      #(0, None)
    },
    on_message: fn(count, _msg, conn, _deps) {
      let _ = sse.send_event(conn, sse.event("ping"))
      sse.continue_connection(count + 1)
    },
  )
}
```

#### send_event

```gleam
pub fn send_event(connection: SSEConnection, event: Event) -> Result(Nil, Nil)
```

Send an SSE event to the client.

#### event / event_name / event_id / event_retry

```gleam
pub fn event(data: String) -> Event
pub fn event_name(event: Event, name: String) -> Event
pub fn event_id(event: Event, id: String) -> Event
pub fn event_retry(event: Event, retry_ms: Int) -> Event
```

Build structured SSE events. Only `event(data)` is required.

**Example:**
```gleam
sse.event("{\"count\": 42}")
|> sse.event_name("tick")
|> sse.event_id("42")
|> sse.event_retry(5000)
```

#### continue_connection / stop_connection

```gleam
pub fn continue_connection(state: state) -> Action(state, message)
pub fn continue_connection_with_selector(state: state, selector: Selector(message)) -> Action(state, message)
pub fn stop_connection() -> Action(state, message)
```

Control the SSE actor loop. `continue_connection` keeps the actor alive,
`stop_connection` shuts it down.

## Router Functions

### stream_route

```gleam
pub fn stream_route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_fn: fn(Request, context, services) -> Response,
  middleware middleware_list: List(Middleware(context, services)),
) -> Router(context, services)
```

Add a streaming route to the router for any HTTP method.

Registers a route that receives the request body as a stream (Yielder(BitArray))
instead of a buffered string. Use for large file uploads (> 10MB), proxying
external APIs, or any case where you want to process the request body in chunks.

**Parameters:**
- `method`: HTTP method (Post, Put, Patch, etc.)
- `path`: URL path (can include parameters like `"/upload/:id"`)
- `controller`: Controller function to handle the request
- `middleware`: List of middleware to run (can transform stream)

**Behavior:**
- `request.body` is empty `""`
- `request.stream` is `Some(Yielder(BitArray))`
- Body is not buffered - processed as chunks arrive
- Memory usage stays constant regardless of upload size

**Example:**
```gleam
import dream/router.{router, stream_route}
import dream/http/request.{Post, Put}

pub fn create_router() {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: controllers.upload,
    middleware: [],
  )
  |> stream_route(
    method: Put,
    path: "/files/:id",
    controller: controllers.replace_file,
    middleware: [auth],
  )
}
```

### route

```gleam
pub fn route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_fn: fn(Request, context, services) -> Response,
  middleware middleware_list: List(Middleware(context, services)),
) -> Router(context, services)
```

Add a regular buffered route to the router.

For streaming routes, use `stream_route()` instead.

## Yielder Operations

Common operations on streaming data:

### Transform Chunks

```gleam
import gleam/yielder

let uppercase_stream =
  request.stream
  |> yielder.map(uppercase_chunk)

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  chunk
  |> bit_array.to_string()
  |> result.unwrap("")
  |> string.uppercase()
  |> bit_array.from_string()
}
```

### Filter Chunks

```gleam
let non_empty_stream =
  stream
  |> yielder.filter(is_non_empty_chunk)

fn is_non_empty_chunk(chunk: BitArray) -> Bool {
  bit_array.byte_size(chunk) > 0
}
```

### Fold/Reduce

```gleam
let total_bytes =
  stream
  |> yielder.fold(0, add_chunk_size)

fn add_chunk_size(acc: Int, chunk: BitArray) -> Int {
  acc + bit_array.byte_size(chunk)
}
```

### Take Limited

```gleam
let first_100_chunks =
  stream
  |> yielder.take(100)
```

### Chain Streams

```gleam
let header = yielder.single(<<"id,name\n":utf8>>)
let rows = yielder.from_list(data)
  |> yielder.map(to_csv_row)

let full_stream = yielder.append(header, rows)
```

## Server Configuration

### max_body_size

```gleam
pub fn max_body_size(
  server: Server(context, services),
  max_size: Int,
) -> Server(context, services)
```

Set maximum buffered body size in bytes.

**Default:** 10MB (10_000_000 bytes)

**For streaming routes:** This limit doesn't apply (streams can be unlimited)

**Example:**
```gleam
server.new()
  |> max_body_size(100_000_000)  // 100MB for large JSON payloads
  |> listen(3000)
```


## Middleware with Streaming

### Request Stream Transformation

```gleam
pub type Middleware(context, services) {
  Middleware(
    fn(
      Request,
      context,
      services,
      fn(Request, context, services) -> Response,
    ) -> Response
  )
}

pub fn compress_incoming() -> Middleware(context, services) {
  Middleware(compress_incoming_handler)
}

fn compress_incoming_handler(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let compressed_stream = yielder.map(stream, compress_chunk)
      let new_request = Request(..request, stream: Some(compressed_stream))
      next(new_request, context, services)
    }
    None -> next(request, context, services)
  }
}
```

### Response Stream Transformation

```gleam
pub fn log_outgoing_chunks() -> Middleware(context, services) {
  Middleware(log_outgoing_chunks_handler)
}

fn log_outgoing_chunks_handler(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)
  
  case response.body {
    Stream(stream) -> {
      let logged_stream = yielder.map(stream, log_and_return_chunk)
      Response(..response, body: Stream(logged_stream))
    }
    _ -> response
  }
}

fn log_and_return_chunk(chunk: BitArray) -> BitArray {
  io.println("Sending chunk: " <> int.to_string(bit_array.byte_size(chunk)) <> " bytes")
  chunk
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

**Buffered response:**
```gleam
// Loads 100MB into memory
let big_string = generate_100mb_string()
text_response(status.ok, big_string)  // Peak memory: 100MB+
```

**Streaming response:**
```gleam
// Generates on demand
let stream = generate_stream()
stream_response(status.ok, stream, "text/plain")  // Peak memory: ~64KB
```

## Error Handling

### Handle Stream Errors

```gleam
import gleam/yielder

pub fn upload(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      case process_stream_safely(stream) {
        Ok(result) -> text_response(status.ok, result)
        Error(err) -> handle_error(err)
      }
    }
    None -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn process_stream_safely(stream) -> Result(String, Error) {
  stream
  |> yielder.try_fold(0, validate_and_add_chunk_size)
  |> result.map(format_total_bytes_message)
}

fn validate_and_add_chunk_size(acc: Int, chunk: BitArray) -> Result(Int, Error) {
  case is_valid_chunk(chunk) {
    True -> Ok(acc + bit_array.byte_size(chunk))
    False -> Error(InvalidChunk)
  }
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

