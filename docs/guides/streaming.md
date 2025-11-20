# Streaming Responses

Server-Sent Events (SSE) and large file streaming in Dream.

## Server-Sent Events

### Basic SSE

```gleam
import dream/http.{type Request, type Response}
import dream/http/response.{Bytes}
import dream/http/header.{Header}
import dream/context.{AppContext}
import gleam/bytes_tree
import gleam/option.{Some}
import gleam/yielder
import services.{Services}

pub type Event {
  Event(id: String, data: String)
}

pub fn events(request: Request, context: AppContext, services: Services) -> Response {
  let event_stream = create_event_stream(services)
  
  Response(
    status: 200,
    body: Bytes(yielder_to_bytes_tree(event_stream)),
    headers: [
      Header("Content-Type", "text/event-stream"),
      Header("Cache-Control", "no-cache"),
      Header("Connection", "keep-alive"),
    ],
    cookies: [],
    content_type: Some("text/event-stream"),
  )
}

fn create_event_stream(services: Services) -> yielder.Yielder(BitArray) {
  services.events.subscribe()
  |> yielder.map(event_to_sse)
}

fn event_to_sse(event: Event) -> BitArray {
  let data = "data: " <> event_to_json(event) <> "\n\n"  // Helper: Event → JSON string
  <<data:utf8>>
}

fn event_to_json(event: Event) -> String {
  "{\"id\": \"" <> event.id <> "\", \"data\": \"" <> event.data <> "\"}"
}

fn yielder_to_bytes_tree(y: yielder.Yielder(BitArray)) -> bytes_tree.BytesTree {
  yielder.fold(y, bytes_tree.new(), bytes_tree.append)
}
```

### Event Format

SSE format:

```
data: {"type": "post_created", "id": 1}

data: {"type": "post_updated", "id": 1}

```

Each event ends with double newline (`\n\n`).

## Large File Streaming

### CSV Export

```gleam
import dream/http.{type Request, type Response, json_response, ok, internal_server_error}
import dream/http/response.{Bytes}
import dream/http/header.{Header}
import dream/context.{AppContext}
import gleam/list.{List}
import gleam/option.{Some}
import gleam/yielder
import models/product.{list_all, Product}
import services.{Services}
import views/product_view.{list_to_csv_stream}

import dream/http/error.{type Error}
import utilities/response_helpers

pub fn export_csv(request: Request, context: AppContext, services: Services) -> Response {
  let result = {
    let db = services.database.connection
    list_all(db)
  }
  
  case result {
    Ok(products) -> stream_csv(products)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn stream_csv(products: List(Product)) -> Response {
  let csv_stream = list_to_csv_stream(products)
  
  Response(
    status: 200,
    body: Bytes(yielder_to_bytes_tree(csv_stream)),
    headers: [
      Header("Content-Type", "text/csv"),
      Header("Content-Disposition", "attachment; filename=\"products.csv\""),
    ],
    cookies: [],
    content_type: Some("text/csv"),
  )
}
```

### Chunked Responses

```gleam
import gleam/float.{to_string}
import gleam/int.{to_string}
import gleam/list.{List}
import gleam/yielder.{Yielder, from_list, map, prepend}
import types/product.{Product}

pub fn list_to_csv_stream(products: List(Product)) -> Yielder(BitArray) {
  let header = <<"id,name,price,stock\n":utf8>>
  
  from_list(products)
  |> map(product_to_csv_row)
  |> map(string_to_bits)
  |> prepend(header)
}

fn product_to_csv_row(p: Product) -> String {
  int.to_string(p.id)
  <> "," <> p.name
  <> "," <> float.to_string(p.price)
  <> "," <> int.to_string(p.stock)
  <> "\n"
}

fn string_to_bits(s: String) -> BitArray {
  <<s:utf8>>
}
```

## HTTP Client Streaming

### Stream External API

```gleam
import dream/http.{type Request, type Response}
import dream/context.{AppContext}
import dream_http_client/client.{new, method, url}
import dream_http_client/stream.{stream}
import gleam/bit_array.{byte_size}
import gleam/http.{Get}
import gleam/int.{to_string}
import gleam/io.{println}
import services.{Services}

pub fn proxy_stream(request: Request, context: AppContext, services: Services) -> Response {
  new()
  |> method(Get)
  |> url("https://api.example.com/large-file")
  |> stream(handle_chunk)
}

fn handle_chunk(chunk: BitArray) {
  // Process each chunk
  println("Received chunk: " <> to_string(byte_size(chunk)))
}
```

### Download and Stream

```gleam
import dream/http.{type Request, type Response, json_response, ok, bad_gateway}
import dream/http/response.{Bytes}
import dream/http/header.{Header}
import dream/context.{AppContext}
import dream_http_client/client.{new, url, fetch, Response as ClientResponse}
import gleam/option.{Some}
import services.{Services}

pub fn download_external(
  request: Request,
  context: AppContext,
  services: Services,
) -> Response {
  let api_url = "https://api.example.com/data.csv"
  
  case new() |> url(api_url) |> fetch() {
    Ok(response) -> forward_stream(response)
    Error(_) -> json_response(bad_gateway, "{\"error\": \"External service unavailable\"}")
  }
}

fn forward_stream(external_response: ClientResponse) -> Response {
  Response(
    status: 200,
    body: Bytes(external_response.body),
    headers: [
      Header("Content-Type", "text/csv"),
    ],
    cookies: [],
    content_type: Some("text/csv"),
  )
}
```

## Backpressure

For large streams, yielders provide natural backpressure:

```gleam
import dream/http.{type Request, type Response}
import dream/http/response.{Bytes}
import dream/http/header.{Header}
import dream/context.{AppContext}
import gleam/bytes_tree
import gleam/option.{Some}
import gleam/yielder.{Yielder, map, fold}
import models/product.{stream_all}
import services.{Services}

pub fn large_export(request: Request, context: AppContext, services: Services) -> Response {
  // Query returns yielder, not list
  let products_stream = stream_all(services.db)
  
  let csv_stream =
    products_stream
    |> map(product_to_csv_row)
    |> map(string_to_bits)
  
  Response(
    status: 200,
    body: Bytes(yielder_to_bytes_tree(csv_stream)),
    headers: [Header("Content-Type", "text/csv")],
    cookies: [],
    content_type: Some("text/csv"),
  )
}

fn yielder_to_bytes_tree(y: Yielder(BitArray)) -> bytes_tree.BytesTree {
  fold(y, bytes_tree.new(), bytes_tree.append)
}
```

The yielder only fetches more rows as the client consumes them.

## Working Examples

See examples:
- [examples/streaming/](../../examples/streaming/) - HTTP client streaming
- [examples/cms/](../../examples/cms/) - SSE event feed
- [examples/multi_format/](../../examples/multi_format/) - CSV streaming

## See Also

- [Multiple Formats](multiple-formats.md) - Different response formats
- [File Uploads](#) - This guide (you're here)

