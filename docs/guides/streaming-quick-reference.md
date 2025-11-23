# Streaming Quick Reference

Quick copy-paste patterns for common streaming tasks.

## Upload File (Ingress)

```gleam
import dream/router.{router, stream_route}
import dream/http/request.{type Request, Post}
import dream/http/response.{text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/option.{None, Some}
import gleam/yielder

// Router
pub fn create_router() {
  router
  |> stream_route(method: Post, path: "/upload", controller: upload_file, middleware: [])
}

// Controller
pub fn upload_file(request: Request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      let total_bytes = yielder.fold(stream, 0, add_chunk_size)
      
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes"
      )
    }
    None -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn add_chunk_size(acc: Int, chunk: BitArray) -> Int {
  acc + bit_array.byte_size(chunk)
}
}
```

## Download/Export CSV (Egress)

```gleam
import dream/http/response.{stream_response}
import dream/http/status
import gleam/yielder
import gleam/float
import gleam/int

pub fn export_csv(request, context, services) {
  let result = query_products(services.db)
  
  case result {
    Ok(products) -> {
      let csv_stream = products_to_csv_stream(products)
      stream_response(status.ok, csv_stream, "text/csv")
    }
    Error(err) -> handle_error(err)
  }
}

fn products_to_csv_stream(products: List(Product)) -> yielder.Yielder(BitArray) {
  let header = "id,name,price\n"
  
  yielder.from_list([header, ..list.map(products, product_to_csv_row)])
  |> yielder.map(string_to_bitarray)
}

fn string_to_bitarray(row: String) -> BitArray {
  <<row:utf8>>
}

fn product_to_csv_row(p: Product) -> String {
  int.to_string(p.id) <> "," <> p.name <> "," <> float.to_string(p.price) <> "\n"
}
```

## Server-Sent Events

```gleam
import dream/http/response.{sse_response}
import dream/http/status
import gleam/yielder
import gleam/int

pub fn events(request, context, services) {
  let event_stream =
    services.events.subscribe()
    |> yielder.map(format_event_as_sse)
  
  sse_response(status.ok, event_stream, "text/event-stream")
}

fn format_event_as_sse(event: Event) -> BitArray {
  <<"data: ", event.data:utf8, "\n\n":utf8>>
}
```

## Transform Incoming Stream

```gleam
pub fn uppercase_middleware(request, context, services, next) {
  case request.stream {
    Some(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let new_request = Request(..request, stream: Some(uppercase_stream))
      next(new_request, context, services)
    }
    None -> next(request, context, services)
  }
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  chunk
  |> bit_array.to_string()
  |> result.unwrap("")
  |> string.uppercase()
  |> bit_array.from_string()
}
```

## Transform Outgoing Stream

```gleam
pub fn compress_middleware(request, context, services, next) {
  let response = next(request, context, services)
  
  case response.body {
    Stream(stream) -> {
      let compressed_stream =
        stream
        |> yielder.map(compress_chunk)
      
      Response(..response, body: Stream(compressed_stream))
    }
    _ -> response
  }
}
```

## Proxy Stream

```gleam
pub fn proxy(request, context, services) -> Response {
  // Simulate proxying from external API
  let stream =
    yielder.from_list([
      "Chunk 1\n",
      "Chunk 2\n",
      "Chunk 3\n",
    ])
    |> yielder.map(string_to_bitarray)
  
  stream_response(status.ok, stream, "text/plain")
}

fn string_to_bitarray(s: String) -> BitArray {
  <<s:utf8>>
}
```

## Save Upload to File

```gleam
import simplifile

pub fn save_upload(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> save_stream_to_disk(stream)
    None -> text_response(status.bad_request, "Expected file upload")
  }
}

fn save_stream_to_disk(stream: yielder.Yielder(BitArray)) -> Response {
  let file_path = "uploads/" <> generate_filename()
  
  use file <- result.try(simplifile.create(file_path))
  use _ <- result.try(write_stream_to_file(stream, file))
  Ok(text_response(status.ok, "File saved: " <> file_path))
}
|> result.unwrap_error(text_response(status.internal_server_error, "Save failed"))

fn write_stream_to_file(stream: yielder.Yielder(BitArray), file) -> Result(Nil, simplifile.FileError) {
  yielder.try_fold(stream, file, append_chunk)
  |> result.map(fn(_) { Nil })
}

fn append_chunk(file, chunk: BitArray) -> Result(file, simplifile.FileError) {
  use _ <- result.try(simplifile.append_bits(file, chunk))
  Ok(file)
}
}
```

## Validate Upload (First Chunk)

```gleam
pub fn upload_image(request, context, services) -> Response {
  case request.stream {
    Some(stream) -> {
      case validate_and_process(stream) {
        Ok(file_id) -> json_response(status.created, "{\"file_id\": \"" <> file_id <> "\"}")
        Error(InvalidFileType) -> text_response(status.unprocessable_entity, "Not an image")
        Error(_) -> text_response(status.internal_server_error, "Upload failed")
      }
    }
    None -> text_response(status.bad_request, "Expected image upload")
  }
}

fn validate_and_process(stream) -> Result(String, Error) {
  // Check first chunk for magic bytes
  case yielder.step(stream) {
    yielder.Next(first_chunk, rest) -> {
      case is_valid_image_header(first_chunk) {
        True -> {
          // Reconstruct and process stream
          let full_stream = yielder.prepend(rest(), first_chunk)
          save_image_stream(full_stream)
        }
        False -> Error(InvalidFileType)
      }
    }
    yielder.Done -> Error(EmptyUpload)
  }
}

fn is_valid_image_header(chunk: BitArray) -> Bool {
  // Check for PNG magic bytes
  case chunk {
    <<0x89, 0x50, 0x4E, 0x47, rest:bits>> -> True
    <<0xFF, 0xD8, 0xFF, rest:bits>> -> True  // JPEG
    _ -> False
  }
}
```

## Server Configuration

```gleam
import dream/servers/mist/server.{
  bind, listen, max_body_size, read_timeout, router, services,
}

pub fn main() {
  server.new()
  |> services(app_services)
  |> router(app_router)
  |> max_body_size(100_000_000)  // 100MB for buffered routes
  |> read_timeout(300_000)        // 5 minutes for uploads
  |> bind("localhost")
  |> listen(3000)
}
```

## Common Patterns

### Pattern: Large CSV Export

```gleam
pub fn export_users(request, context, services) {
  let result = user_model.list_all(services.db)
  
  case result {
    Ok(users) -> {
      let header = yielder.single(<<"id,name,email\n":utf8>>)
      let rows =
        yielder.from_list(users)
        |> yielder.map(user_to_csv_row)
        |> yielder.map(string_to_bitarray)
      
      let csv_stream = yielder.append(header, rows)
      
      stream_response(status.ok, csv_stream, "text/csv")
    }
    Error(err) -> handle_error(err)
  }
}

fn string_to_bitarray(row: String) -> BitArray {
  <<row:utf8>>
}
  }
}
```

### Pattern: Progress Updates

```gleam
pub fn long_task(request, context, services) {
  let progress_stream =
    execute_task_with_updates(services.task_queue)
    |> yielder.map(percent_to_sse_event)
  
  sse_response(status.ok, progress_stream, "text/event-stream")
}

fn percent_to_sse_event(percent: Int) -> BitArray {
  let event = "data: {\"progress\": " <> int.to_string(percent) <> "}\n\n"
  <<event:utf8>>
}
```

### Pattern: Conditional Streaming

```gleam
pub fn get_data(request, context, services) {
  let format = get_format_from_query(request)
  
  case format {
    "csv" -> {
      let stream = data_to_csv_stream(services.db)
      stream_response(status.ok, stream, "text/csv")
    }
    "json" -> {
      let data = fetch_all_data(services.db)
      json_response(status.ok, data_to_json(data))
    }
    _ -> text_response(status.ok, "text")
  }
}
```

## Testing Streaming

```gleam
import gleeunit/should

pub fn stream_response_yields_chunks_test() {
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

## See Also

- [Streaming Guide](streaming.md) - Complete guide
- [Streaming API Reference](../reference/streaming-api.md) - Full API docs
- [Examples](../../examples/streaming_capabilities/) - Working code

