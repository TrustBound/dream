# API Reference

**Quick reference for Dream's public APIs. For when you know what you're looking for.**

## Core Modules

### `dream/core/router`

Router configuration and route definitions.

**Types:**

```gleam
pub type Router(context, services)
pub type Route(context, services)
pub type Middleware(context, services)
pub type EmptyServices
```

**Functions:**

```gleam
// Create empty router
pub fn router() -> Router(context, services)

// Add route
pub fn route(
  router: Router(context, services),
  method: Method,
  path: String,
  controller: fn(Request, context, services) -> Response,
  middleware: List(Middleware(context, services)),
) -> Router(context, services)
```

**Example:**

```gleam
import dream/core/router.{router, route}
import dream/core/http/transaction.{Get, Post}

let my_router =
  router
  |> route(method: Get, path: "/", controller: index, middleware: [])
  |> route(method: Post, path: "/users", controller: create_user, middleware: [auth])
```

### `dream/core/http/transaction`

Request and response types and utilities.

**Types:**

```gleam
pub type Request
pub type Response
pub type Method  // Get, Post, Put, Delete, Patch, Head, Options
```

**Request Functions:**

```gleam
// Extract path parameter
pub fn get_param(request: Request, name: String) -> Result(String, Nil)

// Get header value
pub fn get_header(headers: List(Header), name: String) -> Option(String)
```

**Response Functions:**

```gleam
// Create responses
pub fn text_response(status: Status, body: String) -> Response
pub fn json_response(status: Status, body: String) -> Response
pub fn html_response(status: Status, body: String) -> Response
pub fn empty_response(status: Status) -> Response
```

**Example:**

```gleam
import dream/core/http/transaction.{type Request, type Response, get_param, text_response}
import dream/core/http/statuses.{ok_status}

pub fn show(request: Request, context: Context, services: Services) -> Response {
  let assert Ok(id) = get_param(request, "id")
  text_response(ok_status(), "User " <> id)
}
```

### `dream/core/http/statuses`

HTTP status code helpers.

**Success (2xx):**

```gleam
pub fn ok_status() -> Success                      // 200
pub fn created_status() -> Success                 // 201
pub fn accepted_status() -> Success                // 202
pub fn no_content_status() -> Success              // 204
```

**Client Errors (4xx):**

```gleam
pub fn bad_request_status() -> ClientError         // 400
pub fn unauthorized_status() -> ClientError        // 401
pub fn forbidden_status() -> ClientError           // 403
pub fn not_found_status() -> ClientError           // 404
pub fn method_not_allowed_status() -> ClientError  // 405
pub fn conflict_status() -> ClientError            // 409
pub fn unprocessable_entity_status() -> ClientError  // 422
pub fn too_many_requests_status() -> ClientError   // 429
```

**Server Errors (5xx):**

```gleam
pub fn internal_server_error_status() -> ServerError  // 500
pub fn not_implemented_status() -> ServerError        // 501
pub fn bad_gateway_status() -> ServerError            // 502
pub fn service_unavailable_status() -> ServerError    // 503
pub fn gateway_timeout_status() -> ServerError        // 504
```

### `dream/core/context`

Default context type.

**Type:**

```gleam
pub type AppContext {
  AppContext(request_id: String)
}
```

You can define custom context types for your application.

## Server Module

### `dream/servers/mist/server`

Mist HTTP server adapter.

**Functions:**

```gleam
// Create new server instance
pub fn new() -> Dream(MistServer, context, services)

// Configure context
pub fn context(dream: Dream(s, c, svc), context: c) -> Dream(s, c, svc)

// Configure services
pub fn services(dream: Dream(s, c, svc), services: svc) -> Dream(s, c, svc)

// Set router
pub fn router(dream: Dream(s, c, svc), router: Router(c, svc)) -> Dream(s, c, svc)

// Bind to host
pub fn bind(dream: Dream(s, c, svc), host: String) -> Dream(s, c, svc)

// Start listening
pub fn listen(dream: Dream(s, c, svc), port: Int) -> Result(Nil, Error)
```

**Example:**

```gleam
import dream/servers/mist/server as dream
import dream/core/context.{AppContext}

pub fn main() {
  dream.new()
  |> dream.context(AppContext(request_id: ""))
  |> dream.services(initialize_services())
  |> dream.router(create_router())
  |> dream.bind("localhost")
  |> dream.listen(3000)
}
```

## Utilities

### `dream/utilities/http/client`

HTTP client with builder pattern.

**Types:**

```gleam
pub type ClientRequest
```

**Builder Functions:**

```gleam
// Create new client request
pub const new: ClientRequest

// Configure request
pub fn method(req: ClientRequest, method: http.Method) -> ClientRequest
pub fn scheme(req: ClientRequest, scheme: http.Scheme) -> ClientRequest
pub fn host(req: ClientRequest, host: String) -> ClientRequest
pub fn port(req: ClientRequest, port: Int) -> ClientRequest
pub fn path(req: ClientRequest, path: String) -> ClientRequest
pub fn query(req: ClientRequest, query: String) -> ClientRequest
pub fn add_header(req: ClientRequest, name: String, value: String) -> ClientRequest
pub fn body(req: ClientRequest, body: String) -> ClientRequest
```

**Example:**

```gleam
import dream/utilities/http/client
import gleam/http

let request =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.add_header("Authorization", "Bearer token")
```

### `dream/utilities/http/client/fetch`

Non-streaming HTTP requests.

**Functions:**

```gleam
pub fn request(req: ClientRequest) -> Result(String, String)
```

**Example:**

```gleam
import dream/utilities/http/client/fetch as fetch_module

case fetch_module.request(req) {
  Ok(body) -> // Handle response body
  Error(error) -> // Handle error
}
```

### `dream/utilities/http/client/stream`

Streaming HTTP requests.

**Functions:**

```gleam
pub fn stream_request(req: ClientRequest) -> Yielder(BytesTree)
```

**Example:**

```gleam
import dream/utilities/http/client/stream as stream_module
import gleam/yielder

stream_module.stream_request(req)
|> yielder.each(fn(chunk) {
  // Process each chunk as it arrives
})
```

## Validators

### `dream/validators/json_validator`

JSON request validation.

**Functions:**

```gleam
// Validate JSON body, return Result
pub fn validate(
  body: String,
  decoder: Decoder(a),
) -> Result(a, ValidationError)

// Validate JSON body, return Result(data) or Response with error
pub fn validate_or_respond(
  body: String,
  decoder: Decoder(a),
) -> Result(a, Response)

// Convert ValidationError to Response
pub fn error_response(error: ValidationError) -> Response
```

**Example:**

```gleam
import dream/validators/json_validator.{validate_or_respond}
import gleam/dynamic/decode

let decoder = {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

case validate_or_respond(request.body, decoder) {
  Error(response) -> response  // Auto-formatted error
  Ok(data) -> {
    let #(name, email) = data
    // Use validated data
  }
}
```

## Services

### `dream/services/postgres/response`

PostgreSQL response helpers that convert `Result` to `Response`.

**Functions:**

```gleam
// Single row - 200 if found, 404 if not, 500 on error
pub fn one_row(
  result: Result(pog.Returned(row), pog.QueryError),
  encoder: fn(row) -> json.Json,
) -> Response

// Multiple rows - 200 with array, 500 on error
pub fn many_rows(
  result: Result(pog.Returned(row), pog.QueryError),
  encoder: fn(row) -> json.Json,
) -> Response

// Success/failure - 200 on success, 500 on error
pub fn success(result: Result(pog.Returned(a), pog.QueryError)) -> Response
```

**Example:**

```gleam
import dream/services/postgres/response

// Get single user
user.get(db, id) |> response.one_row(user.encode)

// List all users
user.list(db) |> response.many_rows(user.encode_list)

// Delete user
user.delete(db, id) |> response.success
```

### `dream/utilities/json/encoders`

JSON encoding utilities for common types.

**Functions:**

```gleam
pub fn optional_string(opt: Option(String)) -> json.Json
pub fn optional_int(opt: Option(Int)) -> json.Json
pub fn optional_float(opt: Option(Float)) -> json.Json
pub fn optional_bool(opt: Option(Bool)) -> json.Json
pub fn timestamp(opt: Option(Timestamp)) -> json.Json
```

**Example:**

```gleam
import dream/utilities/json/encoders
import gleam/json

json.object([
  #("name", json.string(user.name)),
  #("age", encoders.optional_int(user.age)),
  #("bio", encoders.optional_string(user.bio)),
  #("created_at", encoders.timestamp(user.created_at)),
])
```

## Further Reading

- [Architecture](architecture.md) - How components fit together
- [Guides](../guides/) - Topic-focused how-tos
- [Tutorials](../tutorials/) - Step-by-step guides

---

**[← Back: Documentation](../../README.md)**

