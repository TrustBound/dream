# Tutorial: HTTP Client

**Time:** 15 minutes  
**Prerequisites:** [Basic Routing](basic-routing.md) completed  
**Example code:** `src/examples/streaming/`

Time to make HTTP requests to external APIs. Dream includes an HTTP client with two modes: streaming and non-streaming. Same builder pattern you've seen everywhere else. No surprises.

## What We're Building

A simple API that demonstrates:
- **Non-streaming requests** - Get the full response at once
- **Streaming requests** - Process response chunks as they arrive
- **Builder pattern** - Configure requests the same way you configure routes
- **Error handling** - Deal with network failures gracefully

Both use HTTPS via Erlang's `httpc`. Battle-tested. Reliable.

## When to Use Which

**Non-streaming (Fetch):**
- Small responses that fit in memory
- You need the complete response before processing
- Simple API calls that return JSON
- Most REST APIs

**Streaming:**
- Large responses (files, bulk exports)
- You can process data as it arrives
- Memory-constrained environments
- Real-time data feeds

## Project Structure

```
src/
  your_app/
    controllers/
      stream_controller.gleam
    main.gleam
    router.gleam
    services.gleam
```

## Step 1: Non-Streaming Requests

Create `src/your_app/controllers/stream_controller.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/statuses.{internal_server_error_status, ok_status}
import dream/core/http/transaction.{type Request, type Response, text_response}
import dream/core/router.{type EmptyServices}
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import gleam/http

pub fn fetch_example(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Build the request using builder pattern
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
    |> client.add_header("User-Agent", "Dream-Tutorial")
    |> client.add_header("Accept", "application/json")

  // Make the request
  case fetch_module.request(req) {
    Ok(body) -> text_response(ok_status(), "Response:\n\n" <> body)
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}
```

Simple. Build a request. Make a request. Handle the response.

The builder pattern should feel familiar:

```gleam
client.new
  |> client.method(http.Get)       // GET, POST, PUT, DELETE, etc.
  |> client.scheme(http.Https)     // http or https
  |> client.host("api.example.com")
  |> client.port(443)              // Optional, defaults to 80/443
  |> client.path("/api/v1/users")
  |> client.query("page=1&limit=10")  // Optional query string
  |> client.add_header("Authorization", "Bearer token")
  |> client.body("{\"name\": \"Alice\"}")  // For POST/PUT
```

Same pattern as server configuration, router configuration, everything.

## Step 2: Streaming Requests

Add to the same controller file:

```gleam
import dream/utilities/http/client/stream as stream_module
import gleam/bit_array
import gleam/bytes_tree
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder

pub fn stream_example(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Build the request (same as non-streaming)
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
    |> client.add_header("User-Agent", "Dream-Streaming")

  // Stream the response chunks
  let chunks = stream_module.stream_request(req) |> yielder.to_list

  // Process chunks
  let body_string =
    chunks
    |> list.map(chunk_to_string)
    |> string.join("")

  text_response(ok_status(), "Streamed response:\n\n" <> body_string)
}

fn chunk_to_string(chunk: bytes_tree.BytesTree) -> String {
  bytes_tree.to_bit_array(chunk)
  |> bit_array.to_string
  |> result.unwrap("")
}
```

`stream_request()` returns a `Yielder` that produces chunks as they arrive. You can process them one at a time or collect them all like we did here.

For truly large responses, you'd process chunks incrementally:

```gleam
stream_module.stream_request(req)
|> yielder.each(fn(chunk) {
  // Process this chunk
  save_chunk_to_file(chunk)
  // Or stream it to the client
  // Or aggregate it
})
```

## Step 3: Wire Up the Router

Create `src/your_app/router.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import your_app/controllers/stream_controller

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    controller: stream_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/fetch",
    controller: stream_controller.fetch_example,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream",
    controller: stream_controller.stream_example,
    middleware: [],
  )
}
```

Create the index controller for navigation:

```gleam
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(
    ok_status(),
    "HTTP Client Examples\n\n"
      <> "Routes:\n"
      <> "  GET /fetch - Non-streaming request\n"
      <> "  GET /stream - Streaming request\n",
  )
}
```

## Step 4: Services and Main

Create `src/your_app/services.gleam`:

```gleam
import dream/core/router.{type EmptyServices, EmptyServices}

pub fn initialize_services() -> EmptyServices {
  EmptyServices
}
```

Create `src/your_app/main.gleam`:

```gleam
import dream/core/context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import your_app/router.{create_router}
import your_app/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3003)
}
```

## Step 5: Test It

Run your server:

```bash
gleam run
```

Test the non-streaming endpoint:

```bash
curl http://localhost:3003/fetch
# Output: Response:
#
# {
#   "args": {},
#   "headers": {
#     "User-Agent": "Dream-Tutorial",
#     ...
#   },
#   ...
# }
```

Test the streaming endpoint:

```bash
curl http://localhost:3003/stream
# Output: Streamed response:
#
# {... same JSON response but streamed in chunks ...}
```

## Making POST Requests

For POST/PUT requests with JSON bodies:

```gleam
import gleam/json

pub fn create_user(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Build JSON payload
  let payload =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
    ])
    |> json.to_string

  // Make POST request
  let req =
    client.new
    |> client.method(http.Post)
    |> client.scheme(http.Https)
    |> client.host("api.example.com")
    |> client.path("/users")
    |> client.add_header("Content-Type", "application/json")
    |> client.add_header("Authorization", "Bearer your-token")
    |> client.body(payload)

  case fetch_module.request(req) {
    Ok(body) -> text_response(ok_status(), "Created: " <> body)
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}
```

## Query Parameters

Add query params to your requests:

```gleam
let req =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/search")
  |> client.query("q=gleam&page=1&limit=50")
```

Or build them programmatically:

```gleam
import gleam/list
import gleam/string
import gleam/uri

let params = [
  #("q", "gleam"),
  #("page", "1"),
  #("limit", "50"),
]

let query_string =
  params
  |> list.map(fn(pair) {
    let #(key, value) = pair
    uri.percent_encode(key) <> "=" <> uri.percent_encode(value)
  })
  |> string.join("&")

let req =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/search")
  |> client.query(query_string)
```

## Error Handling

The client returns `Result(String, String)` for non-streaming and `Yielder(BytesTree)` for streaming.

Handle errors appropriately:

```gleam
case fetch_module.request(req) {
  Ok(body) -> {
    // Parse the response
    case json.decode(body, my_decoder) {
      Ok(data) -> // Use the data
      Error(_) -> text_response(
        internal_server_error_status(),
        "Invalid JSON response",
      )
    }
  }
  Error(error) -> {
    // Log the error, retry, whatever
    io.println("HTTP request failed: " <> error)
    text_response(
      internal_server_error_status(),
      "External API unavailable",
    )
  }
}
```

## Using With Services

In real applications, you'd inject HTTP clients via services:

```gleam
// services.gleam
import dream/utilities/http/client

pub type Services {
  Services(
    database: DatabaseService,
    api_client: client.ClientRequest,
  )
}

pub fn initialize_services() -> Services {
  let api_client =
    client.new
    |> client.scheme(http.Https)
    |> client.host("api.example.com")
    |> client.add_header("Authorization", "Bearer " <> api_token)

  Services(
    database: init_database(),
    api_client: api_client,
  )
}
```

Then in controllers:

```gleam
pub fn fetch_users(request, context, services) {
  let req =
    services.api_client
    |> client.path("/users")
    |> client.query("active=true")

  case fetch_module.request(req) {
    Ok(body) -> // Handle response
    Error(error) -> // Handle error
  }
}
```

This lets you:
- Configure base URL once
- Share authentication headers
- Mock the client in tests
- Swap implementations easily

## Common Patterns

### Retry Logic

```gleam
pub fn fetch_with_retry(req, max_attempts) {
  do_fetch_with_retry(req, max_attempts, 1)
}

fn do_fetch_with_retry(req, max_attempts, attempt) {
  case fetch_module.request(req) {
    Ok(body) -> Ok(body)
    Error(error) if attempt < max_attempts -> {
      // Wait a bit, then retry
      process.sleep(1000 * attempt)
      do_fetch_with_retry(req, max_attempts, attempt + 1)
    }
    Error(error) -> Error(error)
  }
}
```

### Timeout Handling

The Erlang `httpc` has timeouts built in. If you need custom handling:

```gleam
import gleam/otp/task

pub fn fetch_with_timeout(req, timeout_ms) {
  let task_result =
    task.async(fn() { fetch_module.request(req) })
    |> task.await(timeout_ms)

  case task_result {
    Ok(fetch_result) -> fetch_result
    Error(_timeout) -> Error("Request timed out")
  }
}
```

### Concurrent Requests

Make multiple requests in parallel:

```gleam
import gleam/otp/task

pub fn fetch_all_users(user_ids) {
  user_ids
  |> list.map(fn(id) {
    task.async(fn() {
      let req =
        client.new
        |> client.method(http.Get)
        |> client.scheme(http.Https)
        |> client.host("api.example.com")
        |> client.path("/users/" <> id)

      fetch_module.request(req)
    })
  })
  |> list.map(task.await_forever)
}
```

## What's Next?

You've learned:
- ✅ How to make non-streaming HTTP requests
- ✅ How to make streaming HTTP requests
- ✅ The builder pattern for configuring requests
- ✅ How to handle errors gracefully
- ✅ Common patterns for retry, timeout, and concurrency

**Ready for more?**

- [Guide: Controllers and Models](../guides/controllers-and-models.md) - Architecture deep dive
- [Guide: Testing](../guides/testing.md) - Testing with mock HTTP clients
- [Reference: Architecture](../reference/architecture.md) - How it all fits together

**Want to see the full example?**

Check out `src/examples/streaming/` in the Dream repository for complete working code with both streaming and non-streaming examples.

---

**[← Back: Authentication](authentication.md)** | **[Up: Documentation](../../README.md)**

