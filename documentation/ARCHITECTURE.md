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
pub type Router {
  Router(routes: List(Route))
}

pub type Route {
  Route(
    method: Method,
    path: String,
    handler: fn(Request) -> Response,
    middleware: List(Middleware),
  )
}
```

**Usage**:
```gleam
import dream/core/router.{type Router, add_route, handler, method, new as route, path, router}
import dream/core/http/transaction.Get

pub fn create_router() -> Router {
  router
  |> add_route(
    route
    |> method(Get)
    |> path("/users/:id")
    |> handler(get_user_controller),
  )
}
```

**Features**:
- Builder pattern for route configuration
- Path parameter support (`/users/:id/posts/:post_id`)
- Middleware infrastructure (can be added, but not executed yet)
- Type-safe handler functions

### 2. Server (Builder Pattern)

```gleam
pub type Dream(server) {
  Dream(server: server, router: Router, max_body_size: Int)
}
```

**Mist Server Implementation**:
Dream provides a Mist HTTP server adapter using a builder pattern.

**Usage**:
```gleam
import dream/servers/mist/server.{bind, listen, router} as dream
import gleam/erlang/process

pub fn main() {
  case
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
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

### 4. Middleware (Partial Implementation)

Middleware infrastructure exists but is not yet executed. The type system and builder functions are in place:

```gleam
pub type Middleware {
  Middleware(fn(Request) -> Response)
}
```

**Current Status**:
- ✅ Middleware type is defined
- ✅ Routes have a `middleware: List(Middleware)` field
- ✅ `add_middleware` function exists to add middleware to routes
- ❌ Middleware is **not executed** when routes are matched

**Usage** (infrastructure exists, but middleware won't run yet):
```gleam
import dream/core/router.{add_middleware, handler, method, new as route, path}
import dream/core/http/transaction.Get

route
  |> method(Get)
  |> path("/admin")
  |> add_middleware(authentication_middleware)  // Can be added, but won't execute
  |> handler(admin_controller)
```

**Note**: Middleware execution logic needs to be implemented in `dream.route_request()` to run middleware functions before calling the route handler. This is planned for future implementation.

## Composition Flow

```gleam
import dream/servers/mist/server.{bind, listen, router} as dream
import examples/simple/router.{create_router}
import dream/core/router.{type Router, add_route, handler, method, new as route, path, router}
import dream/core/http/transaction.Get
import gleam/erlang/process

pub fn main() {
  // 1. Create and configure server using builder pattern
  case
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}

// Router configuration
pub fn create_router() -> Router {
  router
  |> add_route(
    route
    |> method(Get)
    |> path("/")
    |> handler(home_controller),
  )
  |> add_route(
    route
    |> method(Get)
    |> path("/users/:id/posts/:post_id")
    |> handler(show_controller),
  )
}
```

## What Dream Provides vs. What You Provide

### Dream Provides:
- Core types (Request, Response, Router, Route, etc.)
- Builder patterns for server, router, and HTTP client
- Mist HTTP server adapter
- HTTP client with streaming and non-streaming support
- Path parameter extraction
- HTTP status code helpers
- Cookie parsing utilities
- Middleware infrastructure (type and builder functions exist, execution not yet implemented)
- Helper functions and utilities
- Documentation and examples

### You Provide:
- **Controller functions** that handle requests
- **Router configuration** using the builder pattern
- **Application-specific** business logic
- **Custom middleware** functions (infrastructure exists, but middleware execution not yet implemented)

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
import dream/servers/mist/server.{bind, listen, router} as dream
import examples/simple/router.{create_router}
import gleam/erlang/process

pub fn main() {
  // Explicit builder pattern shows exactly what's configured
  case
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
```

## Key Architectural Decisions

### Builder Pattern Consistency
Dream uses builder patterns consistently across server, router, and HTTP client:
- **Server**: `dream.new() |> router(...) |> bind(...) |> listen(port)`
- **Router**: `router |> add_route(route |> method(...) |> path(...) |> handler(...))`
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

## Further Reading

- [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) - Full design philosophy and rationale
- `NAMING_CONVENTIONS.md` - Function naming guidelines
- `src/examples/simple/` - Basic routing example
- `src/examples/streaming/` - HTTP client streaming example

