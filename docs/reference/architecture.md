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
router()
|> route(method: Get, path: "/", controller: index, middleware: [])
|> route(method: Post, path: "/users", controller: create, middleware: [auth])
```

**Path parameters:**

Paths like `/users/:id/posts/:post_id` are parsed into patterns. Parameters are extracted and validated via `require_int(request, "id")` or `require_string(request, "id")`, which return `Result` types for safe error handling.

**Parameter Validation:** Path parameters like `:id` are extracted and validated at runtime using functions like `require_int(request, "id")` which return `Result` types. The compiler does not verify that parameter names in your routes match those in your controllers—this is an intentional design decision favoring ergonomic APIs over compile-time guarantees. See [Discussion #15](https://github.com/TrustBound/dream/discussions/15) for exploration of type-safe alternatives.

**Performance:** The router uses a radix trie internally for O(path depth) lookup, making route matching extremely fast regardless of the number of routes. Benchmark results show ~1.3-1.5μs per lookup whether you have 100 or 1000 routes.

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
// Simple apps (no custom context or services needed)
dream.new()
|> router(create_router())
|> bind("localhost")
|> listen(3000)

// With custom context and services
dream.new()
|> context(MyContext(request_id: "", user: None))
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
router() |> route(...) |> route(...)

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

## Model-View-Controller (MVC) Architecture

Dream encourages a clean separation of concerns using the Model-View-Controller pattern. This architecture keeps your code organized, testable, and maintainable as your application grows.

### The Three Layers

**Controllers** handle HTTP concerns:
- Parse and validate request parameters
- Call models to fetch or update data
- Call operations for complex business logic
- Call views to format responses
- Map domain errors to HTTP status codes
- Return `Response` objects

**Models** handle data access:
- Execute database queries (using `dream_postgres` and `squirrel`)
- Convert database rows to domain types
- Return `Result(domain_type, dream.Error)`
- Know nothing about HTTP, views, or business logic

**Views** handle presentation:
- Format domain types as strings (HTML, JSON, CSV, etc.)
- Pure functions with no side effects
- Know nothing about HTTP or data access

### Request Flow

Here's how a typical request flows through the MVC layers:

```
1. Router matches request → finds controller
2. Controller extracts parameters (e.g., `require_int(request, "id")`)
3. Controller calls Model to fetch data
4. Model queries database, returns domain type or error
5. Controller calls View to format data
6. View returns formatted string (HTML, JSON, etc.)
7. Controller wraps string in Response and returns it
```

### Complete Example

Let's trace through a complete example showing all three layers working together:

**Model** (`models/task/task_model.gleam`):
```gleam
import dream/http/error.{type Error, NotFound, InternalServerError}
import dream_postgres/client.{type Connection}
import dream_postgres/query
import models/task/sql
import types/task.{type Task}

pub fn get(db: Connection, task_id: Int) -> Result(Task, Error) {
  case sql.get_task(db, task_id) |> query.first_row() {
    Ok(row) -> Ok(row_to_task(row))
    Error(query.NotFound) -> Error(NotFound("Task not found"))
    Error(query.DatabaseError) -> Error(InternalServerError("Database error"))
  }
}

fn row_to_task(row: sql.GetTaskRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    completed: row.completed,
    // ... other fields
  )
}
```

**View** (`views/task_view.gleam`):
```gleam
import gleam/json
import types/task.{type Task}

pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("completed", json.bool(task.completed)),
  ])
  |> json.to_string()
}

pub fn card(task: Task, tags: List(Tag)) -> String {
  // Composes template components into HTML
  task_components.task_card(task, tags)
}
```

**Controller** (`controllers/tasks_controller.gleam`):
```gleam
import dream/http.{type Request, type Response, require_int, json_response, html_response, ok}
import gleam/result
import models/task/task_model
import utilities/response_helpers
import views/task_view

pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let result = {
    use task_id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, task_id))
    Ok(task)
  }

  case result {
    Ok(task) -> {
      // Check format for content negotiation
      case request.format {
        Some("json") -> json_response(ok, task_view.to_json(task))
        _ -> html_response(ok, task_view.card(task, []))
      }
    }
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

### Separation of Concerns

Each layer has a single, clear responsibility:

- **Controllers** know about HTTP (requests, responses, status codes) but not about SQL or HTML structure
- **Models** know about data (database queries, domain types) but not about HTTP or presentation
- **Views** know about presentation (formatting, templates) but not about HTTP or data access

This separation makes your code:
- **Testable**: Test models without HTTP, test views without databases
- **Reusable**: Use the same model from REST API, GraphQL, or background jobs
- **Maintainable**: Change HTML structure without touching database code
- **Type-safe**: The compiler ensures each layer gets the right types

### When to Use Operations

For simple CRUD operations, the Controller → Model → View flow is sufficient. But when business logic gets complex, use the **Operations** pattern:

**Use Controllers directly when:**
- Simple CRUD (create, read, update, delete)
- Single model operation
- Direct request → model → view flow

**Use Operations when:**
- Coordinating multiple models or services
- Complex business rules or validation
- Reusable logic across multiple endpoints
- Side effects (indexing, notifications, events)

For example, publishing a post might require:
1. Update database (Model)
2. Index in search engine (Service)
3. Send notifications (Service)
4. Broadcast event (Service)

This coordination belongs in an Operation, not a Controller. See [Operations Guide](../guides/operations.md) and [Advanced Patterns](../learn/04-advanced-patterns.md) for details.

### Best Practices

**Controllers:**
- Keep them thin—coordinate, don't calculate
- Use `require_*` functions for parameter validation
- Use flat `use` chains instead of nested `case` statements
- Handle all errors uniformly via `response_helpers.handle_error`

**Models:**
- Return domain types, not SQL row types
- Convert database errors to `dream.Error`
- Keep database logic isolated from business logic
- Use type-safe SQL with `squirrel`

**Views:**
- Pure functions with no side effects
- Accept domain types, return strings
- Handle multiple formats (JSON, HTML, CSV) in the same view module
- Compose templates for reusable HTML components

For detailed patterns and examples, see:
- [Controllers & Models Guide](../guides/controllers-and-models.md) - Detailed MVC patterns
- [Operations Guide](../guides/operations.md) - Complex business logic
- [Multiple Formats Guide](../guides/multiple-formats.md) - Content negotiation

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

## Modules Ecosystem

Dream is modular. Core provides routing and HTTP primitives. Additional functionality lives in separate modules that you can use as needed.

### Core Module: `dream`

The core `dream` package provides:
- Router with pattern matching and middleware
- HTTP types (Request, Response, Header, Cookie)
- Response builders (json_response, html_response, etc.)
- Status constants (ok, created, not_found, etc.)
- Parameter validation (require_int, require_string, etc.)
- JSON validation (validate_json)
- Server adapter (Mist)

### Data Modules

**`dream_postgres`** - PostgreSQL utilities
- Query result helpers (first_row, all_rows)
- Type-safe error handling
- Connection pooling support
- Works with Squirrel-generated SQL queries

```gleam
import dream_postgres/client
import dream_postgres/query

let db = client.from_url("postgresql://localhost/db")
case sql.get_user(db, id) |> query.first_row() {
  Ok(row) -> // Process row
  Error(query.NotFound) -> // Handle not found
  Error(query.DatabaseError) -> // Handle error
}
```

**`dream_opensearch`** - OpenSearch client
- Document indexing and search
- Query builders (match_all, term, match)
- HTTP wrapper for OpenSearch API

```gleam
import dream_opensearch/client
import dream_opensearch/document

let opensearch = client.new("http://localhost:9200")
document.index(opensearch, "logs", "doc-id-123", json_string)
```

### Utility Modules

**`dream_http_client`** - HTTP client with three execution modes
- **Blocking** (`send`) - Complete response at once (JSON APIs)
- **Yielder streaming** (`stream_yielder`) - Sequential chunks (AI responses, file downloads)
- **Message-based streaming** (`stream_messages`) - OTP-compatible concurrent streams
- HTTPS support, configurable timeouts, builder pattern
- Built on Erlang's battle-tested `httpc`

```gleam
import dream_http_client/client
import gleam/http

// Blocking request
let response = client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.timeout(5000)  // 5 second timeout
  |> client.send()

// Streaming request (see module docs for stream_yielder and stream_messages)
```

**`dream_config`** - Configuration management
- Environment variable loading
- .env file support
- Type-safe configuration loading

```gleam
import dream_config/loader

pub fn load_config() -> Result(AppConfig, String) {
  loader.load_dotenv()
  use db_url <- result.try(loader.get_required("DATABASE_URL"))
  let port = loader.get_int("PORT") |> result.unwrap(3000)
  Ok(AppConfig(database_url: db_url, port: port))
}
```

**`dream_json`** - JSON encoding utilities
- JSON encoders for optional values and timestamps
- Convenience functions for common JSON encoding patterns

```gleam
import dream_json/json_encoders
import gleam/json
import gleam/option

json.object([
  #("email", json_encoders.optional_string(option.Some("user@example.com"))),
  #("age", json_encoders.optional_int(option.None)),
])
```

**`dream_ets`** - ETS (Erlang Term Storage) utilities
- In-memory key-value storage
- Process-safe table operations
- Useful for caching, rate limiting, and shared state

### Using Modules

Modules are independent Gleam packages. For local development, add them as path dependencies:

```toml
[dependencies]
dream = { path = "../dream" }
dream_postgres = { path = "../dream/modules/postgres" }
dream_http_client = { path = "../dream/modules/http_client" }
```

Each module has its own README with detailed usage examples. See the `modules/` directory for complete documentation.

### Module Philosophy

Dream modules follow the same principles as core:
- Explicit dependencies (no global state)
- Type-safe APIs
- Builder patterns for configuration
- Clear separation of concerns

Use only what you need. Mix and match modules as your application requires.

## Extending Dream

Want to add functionality?

- **Custom middleware** - Match the middleware signature
- **Custom context** - Define your own context type
- **Custom services** - Add fields to Services type
- **Custom response helpers** - Write functions that return Response

Dream doesn't lock you in. Extend as needed.

## API Stability

Dream is currently in pre-1.0 development. Nothing is considered stable yet, and the API may change between versions.

### Versioning Policy

- **0.x.x versions:** May have breaking changes. Use semantic versioning, but breaking changes are allowed in minor versions during pre-1.0 development.
- **1.0.0 and later:** Will follow semantic versioning strictly. Breaking changes only in major versions.

### What's Unlikely to Change

While nothing is guaranteed until 1.0.0, these core components are unlikely to change significantly:

- **Context system:** The pattern of per-request context passed to controllers
- **Services pattern:** Application-level dependencies injected via Services
- **Request/Response types:** Core HTTP request and response structures
- **Router:** Route matching and middleware chaining patterns

These form the foundation of Dream's architecture and changing them would require significant refactoring of existing applications.

### What May Change

Everything else is subject to change based on feedback and real-world usage:

- Function names and signatures
- Error types and handling
- Response builders
- Parameter validation APIs
- Module APIs
- Server configuration options

### Upgrading Between Versions

When upgrading between 0.x.x versions:
- Review the [CHANGELOG](../CHANGELOG.md) for breaking changes
- Test your application thoroughly
- Update code to match new APIs as needed

We aim to minimize breaking changes, but during pre-1.0 development, we prioritize getting the API right over maintaining backward compatibility.

## Further Reading

- [Design Principles](design-principles.md) - The "why" behind decisions
- [Lesson 2: Building an API](../learn/02-building-api.md) - Models, views, controllers in practice
- [Lesson 3: Adding Auth](../learn/03-adding-auth.md) - Middleware in depth

---

**See Also:**
- [Design Principles](design-principles.md) - Why Dream is built this way
- [Dream vs Mist](dream-vs-mist.md) - What Dream adds over raw Mist

