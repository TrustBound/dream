# Dream Architecture Overview

## Philosophy: Composable Library, Not Framework

Dream is a **composable web library**, not an opinionated framework. We provide clean interfaces, builder patterns, and building blocks. You compose them however you want.

### Core Principles

1. **Consistent builder patterns** - Server, router, and HTTP client all use the same fluent API style
2. **No closures** - All functions use explicit parameter passing
3. **Explicit composition** - Your `main()` shows exactly what's wired together
4. **Type safety first** - Strong typing throughout prevents runtime errors
5. **No magic** - Everything explicit in configuration

## Key Components

### 1. Router (Builder Pattern)

```gleam
pub type Router(context, services) {
  Router(routes: List(Route(context, services)))
}

pub type Route(context, services) {
  Route(
    method: Method,
    path: String,
    handler: fn(Request, context, services) -> Response,
    middleware: List(Middleware(context, services)),
  )
}
```

**Usage**:
```gleam
import dream/core/router.{type Router, route, router}
import dream/core/http/transaction.Get

pub fn create_router() -> Router(AppContext) {
  router
  |> route(
    method: Get,
    path: "/users/:id",
    handler: get_user_controller,
    middleware: [],
  )
}
```

**Features**:
- Builder pattern for route configuration
- Path parameter support (`/users/:id/posts/:post_id`)
- Middleware chaining - middleware executes before route handlers
- Generic context types for type-safe request context
- Type-safe handler functions

### 2. Server (Builder Pattern)

```gleam
pub type Dream(server, context, services) {
  Dream(
    server: server,
    router: Option(Router(context, services)),
    context: context,
    services: Option(services),
    max_body_size: Int,
  )
}
```

**Mist Server Implementation**:
Dream provides a Mist HTTP server adapter using a builder pattern.

**Usage**:
```gleam
import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
    dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
}
```

**Features**:
- Builder pattern for server configuration
- Configurable bind address and router
- Port specified when starting the server via `listen(port)`
- Maximum body size configuration
- Type-safe server startup

### 3. HTTP Client (Builder Pattern)

Dream provides an HTTP client with builder pattern support for both streaming and non-streaming requests.

```gleam
pub type ClientRequest {
  ClientRequest(
    method: http.Method,
    scheme: http.Scheme,
    host: String,
    port: Option(Int),
    path: String,
    query: Option(String),
    headers: List(#(String, String)),
    body: String,
  )
}
```

**Usage - Streaming**:
```gleam
import dream/utilities/http/client
import dream/utilities/http/client/stream
import gleam/http
import gleam/yielder

let req =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("httpbin.org")
  |> client.path("/get")

let chunks = stream.stream_request(req) |> yielder.to_list
```

**Usage - Non-Streaming**:
```gleam
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import gleam/http

let req =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("httpbin.org")
  |> client.path("/get")

case fetch_module.request(req) {
  Ok(body) -> // Handle response
  Error(error) -> // Handle error
}
```

**Features**:
- Builder pattern matching router/server patterns
- HTTPS support via Erlang httpc
- Streaming responses using `gleam/yielder`
- Non-streaming responses for simple use cases

### 4. Middleware (Fully Implemented)

Middleware chaining is fully implemented and executes before route handlers:

```gleam
pub type Middleware(context, services) {
  Middleware(
    fn(Request, context, services, fn(Request, context, services) -> Response) -> Response
  )
}
```

**Current Status**:
- ✅ Middleware type is defined with chaining support
- ✅ Routes have a `middleware: List(Middleware(context))` field
- ✅ `middleware` function accepts a list of middleware functions
- ✅ Middleware **executes** before route handlers
- ✅ Middleware can modify requests and responses
- ✅ Middleware can short-circuit the pipeline (e.g., for authentication failures)

**Usage**:
```gleam
import dream/core/router.{middleware, handler, method, new as route, path, Route}
import dream/core/http/transaction.Get

Route(
  method: Get,
  path: "/admin",
  handler: admin_controller,
  middleware: [],
)
|> middleware([auth_middleware, admin_middleware])
```

**Middleware Example**:
```gleam
pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized")
    option.Some(token) -> {
      case validate_token(token) {
        option.Some(user) -> {
          let updated_context = AuthContext(
            request_id: context.request_id,
            user: option.Some(user),
          )
          next(request, updated_context, services)
        }
        option.None ->
          text_response(unauthorized_status(), "Invalid token")
      }
    }
  }
}
```

**Middleware Execution**: Middleware executes in the order they are added to the route. The first middleware added wraps the outermost layer, then the second middleware wraps inside that, and so on. Finally, the route handler is called.

## Composition Flow

```gleam
import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
  // 1. Create and configure server using builder pattern
    dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
}

// Router configuration
pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    handler: home_controller,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    handler: show_controller,
    middleware: [],
  )
}

## What Dream Provides vs. What You Provide

### Dream Provides:
- Core types (Request(context), Response, Router(context), Route(context), etc.)
- Generic context system for type-safe request context
- Default `AppContext` with `request_id`
- Builder patterns for server, router, and HTTP client
- Mist HTTP server adapter
- HTTP client with streaming and non-streaming support
- Path parameter extraction
- HTTP status code helpers
- Cookie parsing utilities
- Middleware chaining infrastructure and execution
- Helper functions and utilities
- Documentation and examples

### You Provide:
- **Controller functions** that handle requests (Rails-style actions like `index`, `show`)
- **Router configuration** using the builder pattern
- **Application-specific** business logic
- **Custom context types** (if you need more than the default `AppContext`)
- **Custom middleware** functions that match the middleware signature

## Design Benefits

1. **Consistent builder patterns** - Server, router, and client all use the same fluent API style
2. **Type-safe** - Strong typing throughout prevents runtime errors
3. **No magic** - Everything explicit in `main()` and router configuration
4. **Simple composition** - Builder pattern makes configuration clear and readable
5. **Modular** - HTTP client split into logical modules (stream, fetch, internal)
6. **Easy to understand** - Clear separation of concerns

## Comparison to Other Approaches

### Traditional Opinionated Framework
```gleam
// You're forced to use their router, server, everything
pub fn main() {
  Framework.start()  // What server? What router? Who knows!
}
```

### Dream (Composable Library)
```gleam
import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
  // Explicit builder pattern shows exactly what's configured
    dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
}
```

## Key Architectural Decisions

### Builder Pattern Consistency
Dream uses builder patterns consistently across server, router, and HTTP client:
- **Server**: `dream.new() |> router(...) |> bind(...) |> listen(port)`
- **Router**: `router |> route(method: ..., path: ..., handler: ..., middleware: ...)`
- **Client**: `client.new |> method(...) |> scheme(...) |> host(...) |> path(...)`

This provides:
- **Consistency**: Same pattern everywhere makes the API predictable
- **Readability**: Fluent API clearly shows what's being configured
- **Type safety**: Compiler catches configuration errors
- **Composability**: Easy to build up complex configurations

### Modular HTTP Client
The HTTP client is split into logical modules:
- `client.gleam` - Builder pattern and type definitions
- `client/stream.gleam` - Streaming request functionality
- `client/fetch.gleam` - Non-streaming request functionality
- `client/internal.gleam` - Low-level Erlang externals

This separation:
- **Prevents import cycles** - Clear module boundaries
- **Makes dependencies explicit** - Each module has a clear purpose
- **Enables future expansion** - Easy to add new client features

### 5. Request Context System

Dream uses generic types to provide type-safe request context:

```gleam
pub type Request {
  Request(
    // ... HTTP fields only (method, headers, body, etc.) ...
    // No context field - Request is immutable
  )
}

pub type AppContext {
  AppContext(request_id: String)
}
```

**Default Context**:
Dream provides a default `AppContext` that includes a `request_id` for each request.

**Custom Context Example**:
```gleam
pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

pub fn new_context(request_id: String) -> AuthContext {
  AuthContext(request_id: request_id, user: option.None)
}
```

**Usage**:
```gleam
import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/custom_context/router.{create_router}
import examples/custom_context/services.{initialize_services}

pub fn main() {
    dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
    |> bind("localhost")
    |> listen(3001)
}
```

**Accessing Context in Controllers**:
```gleam
pub fn show(
  request: Request,
  context: AuthContext,
  services: Services,
) -> Response {
  let user = context.user
  // ... use user data ...
  // Access database via services.database
  // Access request data via request.body, request.headers, etc.
}
```

## Further Reading

- [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) - Full design philosophy and rationale
- `NAMING_CONVENTIONS.md` - Function naming guidelines
- `src/examples/simple/` - Basic routing example with default AppContext
- `src/examples/streaming/` - HTTP client streaming example
- `src/examples/custom_context/` - Custom context with authentication middleware example

