[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Stream responses and uploads

# Stream responses and uploads

Some bodies are too big, or too slow, to hold in memory: a CSV export of a whole table, a log that grows while the client reads it, a video upload, an answer that you proxy from another service. You want to send them a chunk at a time, read uploads a chunk at a time, and handle the upload whose connection breaks halfway. This guide does each of those with Dream's `Yielder`-based streams, using `examples/streaming_capabilities` for the real requests and answers, and the tested snippets of Dream for the rest.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Stream or buffer](#stream-or-buffer)
- [Step 1: Stream a response](#step-1-stream-a-response)
- [Step 2: Receive a streamed upload](#step-2-receive-a-streamed-upload)
- [Step 3: Handle an upload that breaks](#step-3-handle-an-upload-that-breaks)
- [Step 4: Transform streams in middleware](#step-4-transform-streams-in-middleware)
- [Step 5: Proxy a stream from another service](#step-5-proxy-a-stream-from-another-service)
- [Accept multipart form uploads](#accept-multipart-form-uploads)
- [Patterns](#patterns)
- [Performance](#performance)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A download that the server writes a line at a time, and a CSV export.
- An upload route that reads the body as a stream and counts its bytes.
- The `400` that the upload controller answers when the stream breaks.
- A middleware that changes a request stream on its way in, and a response stream on its way out.
- A proxy that passes another service's stream to the client.

## Before you start

Read [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) first. You need Dream and `gleam_yielder`:

```sh
gleam add dream gleam_yielder
```

The example runs from the Dream repository with `make run` in `examples/streaming_capabilities`, on port 3000. Its `/proxy` route reads from a mock server that the example starts on port 9876. [The streaming API reference](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/streaming-api.md) lists every type and function, with short recipes. Server-sent events have [their own guide](https://hexdocs.pm/dream/3.0.0/guides/sse.html).

## Stream or buffer


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



### Request Handling

| Feature | Buffered Route | Streaming Route |
|---------|----------------|-----------------|
| Route | `route(...)` | `stream_route(...)` |
| `request.body` | `Text(String)`, or `Bytes(BitArray)` when not UTF-8 | `Stream(Yielder(Result(BitArray, BodyReadError)))` |
| Memory | Loads full body | Processes chunks |
| Max size | Limited by `max_body_size` | Can be unlimited |
| Use for | Forms, JSON APIs | File uploads, large payloads |

### Response Types <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_types.gleam#L6-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Request}
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


## Step 1: Stream a response

The example's `/download` route answers with lines that a `Yielder` makes while the response is sent:

### A streamed download <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L32-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Download and look at the first lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme.sh#L12-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl http://localhost:3000/download > output.txt
head -n 3 output.txt
```

### The first three lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme_output.txt#L2-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Line 1
Line 2
Line 3
```

The status and the headers go out first, then each chunk as the yielder makes it, with `Transfer-Encoding: chunked` on HTTP/1.1.

### Stream a Log

The smallest streaming controller changes a list of lines into a `Yielder(BitArray)` and gives it to `stream_response`. Each line goes to the client as one chunk.

#### Stream log lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_streaming.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{ok, stream_response}
import gleam/bit_array
import gleam/yielder

pub type Services {
  Services(log_store: List(String))
}

pub fn download_log(_request, _context, services: Services) {
  let stream = make_log_stream(services.log_store)
  stream_response(ok, stream, "text/plain")
}

fn make_log_stream(lines: List(String)) -> yielder.Yielder(BitArray) {
  yielder.from_list(lines)
  |> yielder.map(fn(line) { bit_array.from_string(line <> "\n") })
}
```

### Basic Streaming Response

Stream data to the client without loading it all into memory:

#### Stream 1000 lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_download.gleam#L5-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Stream products as CSV <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_csv_export.gleam#L6-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Send a file in 64 KB chunks <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_file_download.gleam#L6-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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


## Step 2: Receive a streamed upload

A normal route reads the whole body before the controller runs. A route made with `stream_route` gives the controller the body as `Stream(yielder)`, where each item is `Ok(chunk)` or, when the read fails, one `Error(BodyReadError)` that ends the stream. The example's upload route:

### The upload route <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/router.gleam#L9-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  router()
  // 1. Ingress Streaming (Uploads)
  // POST /upload - Streams data directly to "disk" (simulated)
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: stream_controller.upload,
    middleware: [],
  )
```

### Count the bytes of the upload <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L15-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Ingress Streaming: Receives a stream and "saves" it (logs size)
pub fn upload(
  request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  case request.body {
    // Consume the stream "saving" it. try_fold stops at an Error item.
    Stream(stream) ->
      stream
      |> yielder.try_fold(0, accumulate_chunk_size)
      |> respond_to_upload
    Text(_) | Bytes(_) ->
      text_response(status.bad_request, "Expected streaming request body")
  }
}
```

### Fold the chunks, and answer the result <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L90-L110"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn accumulate_chunk_size(
  acc: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  // Simulate saving to disk
  acc + bit_array.byte_size(chunk)
}

fn respond_to_upload(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    // The connection broke before the client sent the whole body
    Error(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}
```

`yielder.try_fold` stops at the first `Error`, so `respond_to_upload` gets either the byte count or the read error, never a count of half a body.

### Upload a file <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme.sh#L6-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
echo "Hello World from a large file" > test.txt

# Upload (streaming - no buffering)
curl -X POST --data-binary @test.txt http://localhost:3000/upload
```

### The answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme_output.txt#L1"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Uploaded 30 bytes successfully
```


### Enable Streaming on a Route

Routes must explicitly enable streaming to receive streamed request bodies:

#### Buffered and streaming routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_ingress.gleam#L6-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{
  type BodyReadError, type Request, Bytes, MalformedBody, Post, Put, Stream,
  Text,
}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/result
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
  // Streaming route: the body is a Yielder of Result(BitArray, BodyReadError)
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
- Streaming routes: `request.body` is
  `Stream(Yielder(Result(BitArray, BodyReadError)))`

Each item of the stream is `Ok(chunk)`. When the connection breaks before
the client sent the whole body, the read that fails gives one
`Error(MalformedBody)` item, and then the stream ends. The controller owns
the answer. Because each item is a `Result`, code that uses an item as bytes
does not compile until it handles the `Error`, so a truncated upload is
never handled as a complete one.

The controller below counts the bytes with `yielder.try_fold`, which stops
at the first `Error` item. On an `Error` it answers 400.

### Process Streaming Uploads <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_ingress.gleam#L46-L81"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn upload_stream(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      count_stream_bytes(stream)
      |> create_upload_response
    _ -> text_response(status.bad_request, "Expected streaming request body")
  }
}

// try_fold stops at the first Error item
fn count_stream_bytes(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
) -> Result(Int, BodyReadError) {
  yielder.try_fold(stream, 0, add_chunk_size)
}

fn add_chunk_size(
  total: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  total + bit_array.byte_size(chunk)
}

fn create_upload_response(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    // The connection broke before the client sent the whole body
    Error(MalformedBody) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}
```

### Saving Streamed Files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_saving.gleam#L6-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String, max_upload_bytes: Int)
}

pub type UploadError {
  // The connection broke before the client sent the whole body
  UploadBroke(BodyReadError)
  // Only the limited upload below gives this error
  UploadTooLarge
  WriteFailed(simplifile.FileError)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) ->
      save_stream_to_file(stream, services.upload_path)
      |> handle_save_result(services.upload_path)
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

fn save_stream_to_file(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  path: String,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.create_file(path) |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, item) { append_item(path, item) })
}

fn append_item(
  path: String,
  item: Result(BitArray, BodyReadError),
) -> Result(Nil, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
  simplifile.append_bits(path, chunk) |> result.map_error(WriteFailed)
}

fn handle_save_result(
  result: Result(Nil, UploadError),
  path: String,
) -> Response {
  case result {
    Ok(Nil) -> text_response(status.ok, "File saved successfully")
    Error(error) -> delete_partial_file(path, create_failure_response(error))
  }
}

// Never keep part of an upload: delete the file, then answer
fn delete_partial_file(path: String, response: Response) -> Response {
  case simplifile.delete(path) {
    Ok(Nil) -> response
    Error(_delete_error) ->
      text_response(status.internal_server_error, "Failed to delete the file")
  }
}

fn create_failure_response(error: UploadError) -> Response {
  case error {
    UploadBroke(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
    UploadTooLarge -> text_response(status.bad_request, "Upload is too large")
    WriteFailed(_reason) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
}
```

`append_item` turns an `Error` item into `UploadBroke`, and `try_fold` stops
there. The controller then deletes the partial file and answers 400, so a
broken upload never stays on disk as a complete file.


## Step 3: Handle an upload that breaks

A client can stop in the middle of an upload, or send a body that isn't valid HTTP. Dream doesn't hide that from a stream route: the stream ends with `Error(MalformedBody)`, and the controller decides the answer. This request sends a chunked body whose second chunk size isn't a hex number. It uses bash's `/dev/tcp`, because curl only sends valid bodies:

### Send a broken chunked upload <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme.sh#L24-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
exec 3<>/dev/tcp/localhost/3000
printf 'POST /upload HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\nzz\r\n' >&3
cat <&3
```

### The controller's answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme_output.txt#L17-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
connection: close
content-length: 33
date: (the time of the request)

The upload stopped before its end
```

The controller read `hello`, then got the error, and answered `400`. If it had written the chunks to a file, this is where it deletes the partial file: see "Clean Up Resources" in [Patterns](#patterns). The answer takes 15 seconds to come back for this body: the server waits for the rest of the chunk-size line until its read timeout, then reports the error.

When the connection itself breaks, the client is gone, so nobody sees the answer, but the controller still runs to the end and its clean-up still happens.


## Step 4: Transform streams in middleware

### Send text through the transform <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme.sh#L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -X POST -d "hello world" http://localhost:3000/echo_transform
```

### The upper-cased answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme_output.txt#L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HELLO_WORLD
```

### Transform Request Stream

Middleware can transform streaming request bodies. A middleware is a function
that gets the request, the context, the services and the next handler. It
maps each item with `result.map`, so an `Error` item reaches the controller
unchanged:

#### Uppercase the request stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_middleware.gleam#L6-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type BodyReadError, type Request, Post, Request}
import dream/http/response.{
  type Response, Response, Stream, stream_response, text_response,
}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/function
import gleam/result
import gleam/yielder.{type Yielder}

pub fn uppercase_incoming(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_item)
      let transformed_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(transformed_request, context, services)
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

### Transform Response Stream

Middleware can also transform streaming responses:

#### Replace spaces in the response stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_middleware.gleam#L61-L95"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Bi-Directional Streaming Example <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_middleware.gleam#L97-L122"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
    request.Stream(stream) ->
      stream_response(status.ok, chunks_until_error(stream), "text/plain")
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

// The response is already on its way when a read fails, so it cannot become
// a 400. The echo keeps each Ok chunk and ends at the Error item.
fn chunks_until_error(
  stream: Yielder(Result(BitArray, BodyReadError)),
) -> Yielder(BitArray) {
  yielder.filter_map(stream, function.identity)
}
```

**Flow:**
1. Client sends: `"hello world"`
2. Incoming middleware: `"hello world"` → `"HELLO WORLD"`
3. Controller echoes stream
4. Outgoing middleware: `"HELLO WORLD"` → `"HELLO_WORLD"`
5. Client receives: `"HELLO_WORLD"`


## Step 5: Proxy a stream from another service

### The proxy controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L66-L88"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Proxy Streaming: Streams from mock server
/// Demonstrates using dream_http_client to proxy a stream
pub fn proxy(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  // Use dream_http_client to stream from mock server
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/stream/fast")
    |> client.timeout(15_000)

  // Stream from mock server. A failure ends the stream with an error line,
  // because the 200 status is already sent when the failure occurs.
  let stream = client.stream_yielder(req) |> yielder.map(chunk_or_failure_line)

  stream_response(status.ok, stream, "text/plain")
}
```

The status `200` goes out before the first chunk, so a failure of the upstream stream can't change it any more. The controller turns a failure into a last line of text that says what went wrong.

### Ask the proxy <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme.sh#L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl http://localhost:3000/proxy
```

### The proxied chunks <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/readme_output.txt#L6-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Chunk 1
Chunk 2
Chunk 3
Chunk 4
Chunk 5
Chunk 6
Chunk 7
Chunk 8
Chunk 9
Chunk 10
```


## Accept multipart form uploads

An HTML form with a file field posts `multipart/form-data`. Dream has no multipart parser, so these tested snippets bring small helpers of their own. They buffer the whole body, so use them for files that fit in memory, and a stream route for the rest.

### Basic Upload <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_upload.gleam#L1-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, created, internal_server_error,
  json_response,
}
import dream/http/request.{body_as_string}
import gleam/bit_array
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import simplifile

pub type FileData {
  FileData(original_name: String, content: BitArray, content_type: String)
}

pub fn upload(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> save_file(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

pub fn save_file(file_data: FileData, directory: String) -> Response {
  let filename = generate_filename(file_data.original_name)
  let path = directory <> "/" <> filename

  case simplifile.write_bits(path, file_data.content) {
    Ok(_) -> json_response(created, success_json(filename))
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Save failed\"}")
  }
}

fn success_json(filename: String) -> String {
  json.object([#("filename", json.string(filename))])
  |> json.to_string()
}
```

The upload directory comes from your `Services`. Dream has no multipart
parser, so `parse_multipart` and `generate_filename` are small helpers in the
snippet file. `parse_multipart` reads the body with `body_as_string`, so
these examples only handle files whose content is valid UTF-8. A binary file
arrives as `Bytes`, and `parse_multipart` gives `Error(Nil)` for it.

### Validation

#### File Size <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_validation.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{type Request, type Response, bad_request, json_response}
import gleam/bit_array.{byte_size}
import gleam/json
import snippets/file_uploads_guide_file_type.{validate_file_type}
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, parse_multipart, save_file,
}

// Dream has no constants for these status codes
const payload_too_large = 413

const unsupported_media_type = 415

// 10MB
const max_file_size = 10_000_000

pub fn upload(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> validate_and_save(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_save(file_data: FileData, directory: String) -> Response {
  case validate_file_size(file_data.content) {
    Error(msg) -> json_response(payload_too_large, error_json(msg))
    Ok(_) -> check_file_type(file_data, directory)
  }
}

fn check_file_type(file_data: FileData, directory: String) -> Response {
  case validate_file_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> save_file(file_data, directory)
  }
}

fn validate_file_size(content: BitArray) -> Result(Nil, String) {
  let size = byte_size(content)
  case size > max_file_size {
    True -> Error("File too large (max 10MB)")
    False -> Ok(Nil)
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
```

#### File Type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_file_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/list.{contains}

const allowed_types = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "application/pdf",
]

pub fn validate_file_type(content_type: String) -> Result(Nil, String) {
  case contains(allowed_types, content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported file type")
  }
}
```

### Secure Filenames <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_upload.gleam#L120-L158"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Make a random file name that keeps the original extension.
pub fn generate_filename(original_name: String) -> String {
  let unique_id = string.lowercase(bit_array.base16_encode(random_bytes(16)))
  unique_id <> get_extension(original_name)
}

fn get_extension(filename: String) -> String {
  case string.split(filename, ".") {
    [_, _, ..] as parts -> "." <> sanitize_filename(last_part(parts))
    _ -> ""
  }
}

fn last_part(parts: List(String)) -> String {
  list.last(parts) |> result.unwrap("")
}

/// Replace every character that is not a letter, digit, dot, underscore or
/// dash with an underscore.
pub fn sanitize_filename(filename: String) -> String {
  filename
  |> string.to_graphemes()
  |> list.map(replace_unsafe_character)
  |> string.concat()
}

fn replace_unsafe_character(character: String) -> String {
  case string.contains(safe_characters, character) {
    True -> character
    False -> "_"
  }
}

const safe_characters =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

/// Random bytes from Erlang's crypto module.
@external(erlang, "crypto", "strong_rand_bytes")
fn random_bytes(count: Int) -> BitArray
```

### Storage Options

#### Local Disk <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_multiple.gleam#L40-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn save_to_disk(path: String, content: BitArray) -> Result(String, FileError) {
  simplifile.write_bits(path, content)
  |> result.replace(path)
}
```

#### S3 (or Compatible) <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_s3.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_http_client/client.{
  type ClientRequest, type SendError, add_header, body, host, method, path,
  scheme, send,
}
import gleam/http
import gleam/result

pub fn save_to_s3(
  s3_client: ClientRequest,
  filename: String,
  content: String,
) -> Result(String, SendError) {
  // Pass client.new() as s3_client, or a client with a recorder in tests.
  // For clarity, we build the URL parts directly.
  // If you need true binary uploads, consider base64 encoding the payload or
  // using a client that supports binary request bodies.
  let s3_host = "s3.amazonaws.com"
  let s3_path = "/bucket/" <> filename

  s3_client
  |> method(http.Put)
  |> scheme(http.Https)
  |> host(s3_host)
  |> path(s3_path)
  |> add_header("Content-Type", "application/octet-stream")
  |> body(content)
  |> send()
  |> result.map(fn(_body) { filename })
}
```

### Multiple Files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_multiple.gleam#L1-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, created, internal_server_error,
  json_response,
}
import gleam/json
import gleam/list
import gleam/result
import simplifile.{type FileError}
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, generate_filename, parse_multipart_files,
}

pub fn upload_multiple(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart_files(request) {
    Ok(files) -> save_all_files(files, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid files\"}")
  }
}

fn save_all_files(files: List(FileData), directory: String) -> Response {
  let results = list.map(files, save_file_result(_, directory))

  case result.all(results) {
    Ok(filenames) -> json_response(created, filenames_json(filenames))
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Some files failed\"}")
  }
}

fn filenames_json(filenames: List(String)) -> String {
  json.object([#("filenames", json.array(filenames, json.string))])
  |> json.to_string()
}
```

### Download Endpoint <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_download.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{type Request, type Response, get_param, ok}
import dream/http/error.{type Error, BadRequest, NotFound}
import dream/http/header.{Header}
import dream/http/response.{Bytes, Response}
import gleam/option.{Some}
import gleam/result
import simplifile
import snippets/controllers_guide_response_helpers as response_helpers
import snippets/file_uploads_guide_upload.{type Services, sanitize_filename}

pub fn download(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    // require_string would drop the extension, so read the raw parameter
    use param <- result.try(
      get_param(request, "filename") |> result.map_error(BadRequest),
    )
    let filename = sanitize_filename(param.raw)
    let path = services.upload_directory <> "/" <> filename
    use content <- result.try(read_upload(path))
    Ok(#(content, filename))
  }

  case result {
    Ok(#(content, filename)) -> file_response(ok, content, filename)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn read_upload(path: String) -> Result(BitArray, Error) {
  simplifile.read_bits(path)
  |> result.replace_error(NotFound("File not found"))
}

fn file_response(
  status_code: Int,
  content: BitArray,
  filename: String,
) -> Response {
  Response(
    status: status_code,
    body: Bytes(content),
    headers: [
      Header("Content-Type", "application/octet-stream"),
      Header(
        "Content-Disposition",
        "attachment; filename=\"" <> filename <> "\"",
      ),
    ],
    cookies: [],
    content_type: Some("application/octet-stream"),
  )
}
```

### Image Resizing <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/file_uploads_guide_image.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, internal_server_error, json_response,
}
import gleam/json
import gleam/list
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, FileData, parse_multipart, save_file,
}

// Dream has no constant for this status code
const unsupported_media_type = 415

// For image processing, use FFI to call ImageMagick or similar
@external(erlang, "file_uploads_guide_image_ffi", "resize")
pub fn resize_image(
  content: BitArray,
  width: Int,
  height: Int,
) -> Result(BitArray, Nil)

pub fn upload_image(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> validate_and_resize(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_resize(file_data: FileData, directory: String) -> Response {
  case validate_image_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> resize_and_save(file_data, directory)
  }
}

fn resize_and_save(file_data: FileData, directory: String) -> Response {
  case resize_image(file_data.content, 800, 600) {
    Ok(resized) -> save_file_data(file_data, resized, directory)
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Resize failed\"}")
  }
}

fn save_file_data(
  file_data: FileData,
  content: BitArray,
  directory: String,
) -> Response {
  let updated_file = FileData(..file_data, content: content)
  save_file(updated_file, directory)
}

fn validate_image_type(content_type: String) -> Result(Nil, String) {
  case list.contains(["image/jpeg", "image/png", "image/gif"], content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported image type")
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
```


## Patterns


### 1. Use Appropriate Buffer Sizes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_chunks.gleam#L6-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### 2. Handle Errors Gracefully <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_upload_checks.gleam#L17-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
const max_upload_bytes = 1_000_000

pub type UploadError {
  UploadTooLarge(limit: Int)
  UploadBroke(BodyReadError)
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
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
) -> Result(String, UploadError) {
  stream
  |> yielder.try_fold(0, add_chunk_size)
  |> result.map(format_bytes_message)
}

// An Error item means that the connection broke before the end of the body
fn add_chunk_size(
  total_bytes: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
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
    Error(UploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}
```

### 3. Use Streaming Routes Explicitly <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_ingress.gleam#L83-L103"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

// DO: mark streaming routes explicitly. This body is a Yielder of Results.
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

### 4. Clean Up Resources <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_saving.gleam#L82-L138"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  services: Services,
) -> Response {
  case write_limited_stream(stream, services) {
    Ok(_total_bytes) -> text_response(status.created, "Upload saved")
    Error(error) ->
      delete_partial_file(services.upload_path, create_failure_response(error))
  }
}

fn write_limited_stream(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  services: Services,
) -> Result(Int, UploadError) {
  use _ <- result.try(
    simplifile.create_file(services.upload_path)
    |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, 0, fn(total_bytes, item) {
    write_item(services, total_bytes, item)
  })
}

fn write_item(
  services: Services,
  total_bytes: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
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
```

If the upload is too large, or the stream gives an `Error` item, the
controller deletes the partial file before it answers. `delete_partial_file`
and `create_failure_response` are the functions from "Saving Streamed Files"
above.


### Pattern 1: CSV Export <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_patterns.gleam#L16-L53"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Pattern 2: Progress Updates <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_sse.gleam#L32-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Pattern 3: File Upload with Validation <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_upload_checks.gleam#L71-L181"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ImageError {
  EmptyUpload
  InvalidFileType
  ImageUploadBroke(BodyReadError)
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
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  path: String,
) -> Result(String, ImageError) {
  use full_stream <- result.try(validate_image_header(yielder.step(stream)))
  save_to_storage(full_stream, path)
}

fn validate_image_header(
  step: yielder.Step(
    Result(BitArray, BodyReadError),
    yielder.Yielder(Result(BitArray, BodyReadError)),
  ),
) -> Result(yielder.Yielder(Result(BitArray, BodyReadError)), ImageError) {
  case step {
    yielder.Next(Ok(first_chunk), rest) -> {
      use _ <- result.try(check_is_valid_image(first_chunk))
      Ok(yielder.prepend(rest, Ok(first_chunk)))
    }
    yielder.Next(Error(read_error), _rest) ->
      Error(ImageUploadBroke(read_error))
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
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  path: String,
) -> Result(String, ImageError) {
  use _ <- result.try(
    simplifile.write_bits(path, <<>>) |> result.map_error(SaveFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, item) { append_item(path, item) })
  |> result.replace(path)
  |> result.try_recover(delete_partial_file(path, _))
}

fn append_item(
  path: String,
  item: Result(BitArray, BodyReadError),
) -> Result(Nil, ImageError) {
  use chunk <- result.try(result.map_error(item, ImageUploadBroke))
  simplifile.append_bits(path, chunk) |> result.map_error(SaveFailed)
}

// Never keep part of an upload: delete the file, then give the error
fn delete_partial_file(
  path: String,
  error: ImageError,
) -> Result(String, ImageError) {
  use _ <- result.try(simplifile.delete(path) |> result.map_error(SaveFailed))
  Error(error)
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
    Error(ImageUploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
    Error(_) -> text_response(status.internal_server_error, "Upload failed")
  }
}
```

### Server-sent events and chunked encoding

SSE now has its own dedicated module and guide. See the
**[SSE Guide](https://hexdocs.pm/dream/3.0.0/guides/sse.html)** for a full walkthrough of `upgrade_to_sse`,
event builders, broadcasting, and integration testing.

> **Note:** The old `sse_response` function from `dream/http/response` used
> chunked transfer encoding which stalls after a few events due to TCP
> message contention in the handler process. It has been deprecated in
> favour of `dream/servers/mist/sse.upgrade_to_sse`, which spawns a
> dedicated OTP actor with its own mailbox.

Quick example of the new API:

##### Send a ping event <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_sse.gleam#L6-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

##### Chunked Transfer Encoding

Dream automatically uses HTTP chunked transfer encoding for streaming responses.

**How it works:**

1. Controller returns `stream_response(...)`
2. Dream sends headers with `Transfer-Encoding: chunked`
3. Each yielder value becomes a chunk
4. Client receives chunks as they're generated
5. When the yielder is done, Dream sends the last chunk, which has zero length
6. Over HTTP/1.1 the connection then stays open for the next request, unless
   the client or your response sent `connection: close`. Over HTTP/2 only that
   stream ends

**No configuration needed** - it's automatic for streaming responses.


## Performance

### Memory Usage

#### Buffered response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_patterns.gleam#L55-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// BAD for large exports: the whole CSV is one string in memory
pub fn export_users_buffered(users: List(User)) -> Response {
  let csv =
    string.concat(["id,name,email\n", ..list.map(users, user_to_csv_row)])
  text_response(status.ok, csv)
}
```

#### Streaming response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_patterns.gleam#L62-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Chunk Sizing <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_chunks.gleam#L27-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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


## Test your code

A stream body is a `Yielder` of results, so a test can build one that breaks wherever it wants. This test calls an upload controller from Dream's snippets with a good stream and with one that breaks:

### Test an upload controller with a broken stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_streaming_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Streaming guide: a test of an upload controller with a broken stream
////
//// upload_stream is from test/snippets/streaming_guide_ingress.gleam. A
//// stream body is a Yielder of Result(BitArray, BodyReadError), so a test
//// can build one that breaks in the middle.

import dream/http/request.{
  type BodyReadError, type Request, Http, Http1, MalformedBody, Post, Request,
  Stream,
}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import gleam/yielder
import snippets/streaming_guide_ingress

fn upload(chunks: List(Result(BitArray, BodyReadError))) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/upload_stream",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: Stream(yielder.from_list(chunks)),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("upload_stream", [
    it("counts the bytes of every chunk", fn() {
      // Arrange
      let request = upload([Ok(<<"hello ":utf8>>), Ok(<<"world":utf8>>)])

      // Act
      let response = streaming_guide_ingress.upload_stream(request, Nil, Nil)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Uploaded 11 bytes successfully"))
      |> or_fail_with("two chunks of 6 and 5 bytes should give 11")
    }),
    it("answers 400 when the stream breaks", fn() {
      // Arrange
      let request = upload([Ok(<<"hello ":utf8>>), Error(MalformedBody)])

      // Act
      let response = streaming_guide_ingress.upload_stream(request, Nil, Nil)

      // Assert
      response.status
      |> should
      |> be_equal(400)
      |> or_fail_with("a broken stream should answer 400")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_streaming_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
upload_stream
  ✓ answers 400 when the stream breaks
  ✓ counts the bytes of every chunk

Summary: 2 run, 0 failed, 2 passed in 0ms
```

### Unit Tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_unit_test.gleam#L6-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Integration Tests

The `streaming_capabilities` example checks its download endpoint with this scenario:

#### The download scenario <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/features/streaming.feature#L26-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
    Scenario: Download streamed data
        When I send a GET request to "/download"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/plain"
        And the response should contain "Line 1"
        And the response should contain "Line 1000"
        And the response should contain exactly 1000 lines
```

See [Testing Guide](https://hexdocs.pm/dream/3.0.0/guides/testing.html) for more examples.


## Common pitfalls

### Don't Consume Stream Twice <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_pitfalls.gleam#L15-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Don't Mix Streaming and Buffering <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_pitfalls.gleam#L33-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Don't Forget Error Handling <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/streaming_guide_pitfalls.gleam#L44-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

fn save_stream(stream: Yielder(Result(BitArray, BodyReadError))) -> Response {
  case yielder.try_fold(stream, 0, add_chunk_size) {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Saved " <> int.to_string(total_bytes) <> " bytes",
      )
    // The connection broke before the end of the body
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

The bad controller treats a body that is not a `Stream` as an empty upload.
When the route is registered with `route` instead of `stream_route`, the body
arrives as `Text` or `Bytes`, the client gets `200 Saved 0 bytes`, and nobody
learns that the data was lost.


## Where to go next

- [The streaming API reference](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/streaming-api.md): every streaming type and function, and short recipes.
- [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html).
- [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html).
- [examples/streaming](https://github.com/TrustBound/dream/tree/3.0.0/examples/streaming) and [examples/streaming_capabilities](https://github.com/TrustBound/dream/tree/3.0.0/examples/streaming_capabilities).
