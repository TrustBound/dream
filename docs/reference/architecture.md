# Architecture Reference

**A technical overview of how Dream works. For when you need to understand the internals.**

Dream is a composable library built on simple principles: builder patterns, explicit dependencies, and no magic.

## Core Components

### 1. Router

The router matches HTTP requests to controllers.

**Type:**

```gleam
pub type Router(context, services) {
  Router(routes: List(Route(context, services)))
}

pub type Route(context, services) {
  Route(
    method: Method,
    path: String,
    controller: fn(Request, context, services) -> Response,
    middleware: List(Middleware(context, services)),
  )
}
```

**Builder pattern:**

```gleam
router
|> route(method: Get, path: "/", controller: index, middleware: [])
|> route(method: Post, path: "/users", controller: create, middleware: [auth])
```

**Path parameters:**

Paths like `/users/:id/posts/:post_id` are parsed into patterns. Parameters are extracted and made available via `get_param(request, "id")`.

### 2. Server

Dream provides a Mist HTTP server adapter. Mist is the underlying BEAM web server.

**Type:**

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

**Builder pattern:**

```gleam
dream.new()
|> context(AppContext(request_id: ""))
|> services(initialize_services())
|> router(create_router())
|> bind("localhost")
|> listen(3000)
```

### 3. Middleware

Middleware intercepts requests before they reach controllers.

**Signature:**

```gleam
fn(Request, Context, Services, NextHandler) -> Response

where NextHandler is:
  fn(Request, Context, Services) -> Response
```

**Execution:**

Middleware chains in the order listed. Each middleware can:
- Call `next()` to continue the chain
- Return early to short-circuit

**Example:**

```gleam
pub fn auth_middleware(request, context, services, next) {
  case validate_token(request) {
    Ok(user) -> {
      let updated_context = add_user_to_context(context, user)
      next(request, updated_context, services)
    }
    Error(_) -> unauthorized_response()
  }
}
```

### 4. Context System

Context holds per-request data that middleware can modify.

**Default context:**

```gleam
pub type AppContext {
  AppContext(request_id: String)
}
```

**Custom context:**

```gleam
pub type AuthContext {
  AuthContext(
    request_id: String,
    user: Option(User),
  )
}
```

Middleware receives context, can update it, and pass it to `next()`. Controllers receive the final context.

### 5. Services

Services are application-level dependencies injected at startup.

**Pattern:**

```gleam
pub type Services {
  Services(
    database: DatabaseService,
    // ... other services
  )
}

pub fn initialize_services() -> Services {
  let assert Ok(db) = init_database()
  Services(database: db)
}
```

Injected once in `main()`, used everywhere:

```gleam
dream.new()
|> services(initialize_services())
|> router(create_router())
|> listen(3000)
```

#### Singleton Services

Services that maintain global state across requests should use the singleton pattern. Common use cases:
- Rate limiters
- In-memory caches
- Connection pools
- Global counters/metrics

**Pattern:**

```gleam
import dream/singleton

pub type Services {
  Services(
    rate_limiter_name: process.Name(
      singleton.SingletonMessage(RateLimiterMessage, RateLimiterReply)
Middleware enriches the context before it reaches the controller.

## Type Safety

Dream is heavily typed:

- **Request/Response** - Structured types, not maps
- **Router** - Generic over context and services types
- **Controllers** - Type-checked signatures
- **Path parameters** - Extracted as strings, you convert as needed

The compiler catches most errors before runtime.

## Builder Pattern Consistency

Every configurable component uses the builder pattern:

```gleam
// Server
dream.new() |> router(...) |> bind(...) |> listen(3000)

// Router
router |> route(...) |> route(...)

// HTTP Client
client.new |> method(...) |> host(...) |> path(...)
```

Same pattern. Predictable API. Easy to learn.

## What Dream Provides vs. What You Provide

**Dream provides:**
- Core types (Request, Response, Router)
- Server adapter (Mist)
- HTTP client
- Middleware infrastructure
- Utilities (validation, response helpers, encoders)

**You provide:**
- Controllers
- Models
- Router configuration
- Services initialization
- Business logic

Dream is a library of building blocks. You compose them.

## Design Decisions

### Why No Global Middleware?

Middleware is explicit per route. This makes it obvious which middleware runs on which route. No hunting through files to find what's running.

### Why Separate Context and Services?

- **Context** - Mutable, per-request data (user, request ID)
- **Services** - Immutable, application-level (database, config)

Separating them makes the distinction clear.

### Why No Closures?

Closures hide dependencies. Explicit parameters make dependencies visible:

```gleam
// Bad (closure hides db)
pub fn make_handler(db: Database) -> fn(Request) -> Response {
  fn(request) { use_database(db) }  // db captured in closure
}

// Good (explicit parameter)
pub fn handler(request: Request, services: Services) -> Response {
  let db = services.database
  use_database(db)
}
```

### Why Builder Pattern?

Fluent, readable, and type-safe. Each step transforms the previous value. No global state. No side effects.

## Performance

Dream runs on the BEAM. Performance characteristics:

- **Concurrent connections** - Thousands per core (BEAM is excellent at this)
- **Memory usage** - 1-2GB is normal for production apps
- **Response time** - Microseconds for routing, milliseconds for full request
- **Connection pooling** - Pog handles this efficiently

The BEAM is battle-tested. It scales.

## Extending Dream

Want to add functionality?

- **Custom middleware** - Match the middleware signature
- **Custom context** - Define your own context type
- **Custom services** - Add fields to Services type
- **Custom response helpers** - Write functions that return Response

Dream doesn't lock you in. Extend as needed.

## Further Reading

- [Design Principles](design-principles.md) - The "why" behind decisions
- [Lesson 2: Building an API](../learn/02-building-api.md) - Models, views, controllers in practice
- [Lesson 3: Adding Auth](../learn/03-adding-auth.md) - Middleware in depth

---

**See Also:**
- [Design Principles](design-principles.md) - Why Dream is built this way
- [Dream vs Mist](dream-vs-mist.md) - What Dream adds over raw Mist

