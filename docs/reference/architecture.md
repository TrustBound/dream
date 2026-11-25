# Architecture Reference

**A technical overview of how Dream works. For when you need to understand the internals.**

Dream is a composable library built on simple principles: builder patterns, explicit dependencies, and no magic.

## Core Components

### 1. Router

The router matches HTTP requests to controllers.

`Router(context, services)` is an opaque type. Inside, it is a radix trie of routes. You build it with `router()` and `route()`, and you do not read its fields. Each controller has the type `fn(Request, context, services) -> Response`:

#### Typed controllers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_router.gleam#L15-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_home(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Home")
}

pub fn create_user(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(created, "User created")
}
```

**Builder pattern:**

#### Build a router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_router.gleam#L43-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  |> route(method: Post, path: "/users", controller: create_user, middleware: [
    require_token,
  ])
}
```

**Path parameters:**

Paths like `/users/:id/posts/:post_id` are parsed into patterns. Parameters are extracted and validated via `require_int(request, "id")` or `require_string(request, "id")`, which return `Result` types for safe error handling.

**Parameter Validation:** Path parameters like `:id` are extracted and validated at runtime using functions like `require_int(request, "id")` which return `Result` types. The compiler does not verify that parameter names in your routes match those in your controllers—this is an intentional design decision favoring ergonomic APIs over compile-time guarantees. See [Discussion #15](https://github.com/TrustBound/dream/discussions/15) for exploration of type-safe alternatives.

**Performance:** The router uses a radix trie internally for O(path depth) lookup, making route matching extremely fast regardless of the number of routes. Benchmark results show ~1.3-1.5μs per lookup whether you have 100 or 1000 routes.

### 2. Server

Dream provides a Mist HTTP server adapter. Mist is the underlying BEAM web server.

`Dream(server, context, services, router)` is an opaque type. You build it with the functions in `dream/servers/mist/server`. The `router` parameter is `NoRouter` until you call `router()`, and then it is the `Router(context, services)` you gave. With no context or services, the type of an app with a router is `Dream(Builder(Connection, ResponseData), EmptyContext, EmptyServices, Router(EmptyContext, EmptyServices))`:

#### Server with no context or services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_server.gleam#L49-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_simple_server() -> Dream(
  Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
  Router(EmptyContext, EmptyServices),
) {
  server.new()
  |> server.router(create_router())
  |> server.bind("localhost")
}
```

**Builder pattern:** call `context()` and `services()` before `router()`, then `listen()`. The compiler enforces this order. A router's type includes the context and services types, so `context()` and `services()` accept only an app that has no router yet. `listen()` accepts only an app that has a router.

#### Server with context and services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_server.gleam#L71-L82"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_custom_server() -> Dream(
  Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.bind("localhost")
}
```

The `dream/dream` module has functions that read the settings of a `Dream` value. A server adapter uses them to start the server: `get_server`, `get_router`, `get_context`, `get_services`, `get_max_body_size`, `get_bind_interface` and `get_tls`. `set_tls` sets the certificate and key files. In your application, use `server.tls()` in place of `set_tls`. Before the server starts, the Mist adapter calls `port_probe.is_in_use` from `dream/servers/mist/port_probe` to check if the port is free. Each function has an example in its doc comment on [HexDocs](https://hexdocs.pm/dream/3.0.0/dream/dream.html).

### 3. Middleware

Middleware intercepts requests before they reach controllers.

**Signature:**

#### Middleware signature <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_context.gleam#L26-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
```

`next` has the controller type: `fn(Request, context, services) -> Response`.

**Execution:**

Middleware chains in the order listed. Each middleware can:
- Call `next()` to continue the chain
- Return early to short-circuit

**Example:**

#### Auth middleware that updates the context <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_context.gleam#L26-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case find_user(request, services) {
    Ok(user) -> {
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
    Error(Nil) -> text_response(unauthorized, "Unauthorized")
  }
}

fn find_user(request: Request, services: Services) -> Result(User, Nil) {
  use token <- result.try(
    get_header(request.headers, "Authorization") |> option.to_result(Nil),
  )
  list.key_find(services.users_by_token, token)
}
```

### 4. Context System

Context holds per-request data that middleware can modify.

Dream uses `EmptyContext` until you set a context. Dream also provides `AppContext(request_id: String)` in `dream/context`:

#### Use AppContext <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_server.gleam#L60-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_app_context_server() -> Dream(
  Builder(Connection, ResponseData),
  AppContext,
  EmptyServices,
  Router(AppContext, EmptyServices),
) {
  server.new()
  |> server.context(AppContext(request_id: ""))
  |> server.router(create_router())
}
```

**Custom context:**

#### A custom context <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_context.gleam#L14-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type User {
  User(name: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}
```

Middleware receives context, can update it, and pass it to `next()`. Controllers receive the final context.

### 5. Services

Services are application-level dependencies injected at startup.

**Pattern:**

#### Services built once <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_server.gleam#L23-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Database {
  Database(users: List(User))
}

pub type Services {
  Services(database: Database)
}

pub fn initialize_services() -> Services {
  let database = Database(users: [User(name: "Ada")])
  Services(database: database)
}
```

Injected once in `main()`, used everywhere:

#### Inject services at startup <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_server.gleam#L71-L88"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_custom_server() -> Dream(
  Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.bind("localhost")
}

pub fn main() {
  let assert Ok(Nil) =
    create_custom_server()
    |> server.listen(3000)
}
```

#### Singleton / Global Services

Services that maintain global state across requests should use a single shared
instance per application. Common use cases:
- Rate limiters
- In-memory caches
- Connection pools
- Global counters/metrics

A practical pattern is to use `dream_ets` or a supervised process started at
application boot and referenced from `Services`. See `examples/rate_limiter`
for a complete rate limiting implementation using ETS tables and the Services
pattern.

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

### Server, router and HTTP client builders <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_builders.gleam#L35-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Server
pub fn create_server() -> Dream(
  Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
  Router(EmptyContext, EmptyServices),
) {
  server.new()
  |> server.router(create_router())
  |> server.bind("localhost")
}

// Router
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  |> route(method: Get, path: "/about", controller: show_about, middleware: [])
}

// HTTP client
pub fn create_users_request() -> ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.timeout(5000)
}
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
- Execute database queries (using `dream_postgres` and `dream_sql_generator`)
- Convert database rows to domain types
- Return `Result(domain_type, Error)`, with `Error` from `dream/http/error`
- Know nothing about HTTP, views, or business logic

**Views** handle presentation:
- Format domain types as strings (HTML, JSON, CSV, etc.)
- Pure functions with no side effects
- Know nothing about HTTP or data access

### Request Flow

Here's how a typical request flows through the MVC layers:

```text illustration
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

All three layers share the type `Task(id: Int, title: String, completed: Bool)`. The model reads from a list so that the example runs anywhere. A real model runs a `dream_sql_generator` query through `dream_postgres`.

#### Model: find a task <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_task_model.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Architecture reference: a model
////
//// Finds a task and returns a domain type or a Dream error. It reads from a
//// list so that the example runs anywhere; a real model runs a query.

import dream/http/error.{type Error, NotFound}
import gleam/list
import gleam/result
import snippets/architecture_task.{type Task}

pub fn get_task(tasks: List(Task), task_id: Int) -> Result(Task, Error) {
  list.find(tasks, fn(task) { task.id == task_id })
  |> result.replace_error(NotFound("Task not found"))
}
```

#### View: format a task <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_task_view.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Architecture reference: a view
////
//// Pure functions that format a task as JSON or as HTML.

import gleam/json
import gleam/string
import snippets/architecture_task.{type Task}

pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("completed", json.bool(task.completed)),
  ])
  |> json.to_string()
}

pub fn to_html(task: Task) -> String {
  "<li class=\"task\">" <> escape_html(task.title) <> "</li>"
}

fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}
```

#### Controller: show a task <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_tasks_controller.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Architecture reference: a controller
////
//// Reads the path parameter, calls the model, and calls the view for the
//// format that the client asks for.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, html_response, json_response, ok, require_int,
  text_response,
}
import dream/http/error
import dream/http/header.{get_header}
import gleam/option.{Some}
import gleam/result
import snippets/architecture_task.{type Task}
import snippets/architecture_task_model as task_model
import snippets/architecture_task_view as task_view

pub type Services {
  Services(tasks: List(Task))
}

pub fn show_task(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let task_result = {
    use task_id <- result.try(require_int(request, "id"))
    task_model.get_task(services.tasks, task_id)
  }

  case task_result {
    Ok(task) -> respond_with_task(request, task)
    Error(http_error) ->
      text_response(error.to_status_code(http_error), error.message(http_error))
  }
}

fn respond_with_task(request: Request, task: Task) -> Response {
  case get_header(request.headers, "Accept") {
    Some("application/json") -> json_response(ok, task_view.to_json(task))
    _ -> html_response(ok, task_view.to_html(task))
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

This coordination belongs in an Operation, not a Controller. See [Move a workflow into an operation](../guides/database-api.md#step-13-move-a-workflow-into-an-operation) and [Move a workflow into an operation](../guides/database-api.md#step-13-move-a-workflow-into-an-operation) for details.

### Best Practices

**Controllers:**
- Keep them thin—coordinate, don't calculate
- Use `require_*` functions for parameter validation
- Use flat `use` chains instead of nested `case` statements
- Map errors to responses in one place, for example with `error.to_status_code` and `error.message` from `dream/http/error`

**Models:**
- Return domain types, not SQL row types
- Convert database errors to `Error` from `dream/http/error`
- Keep database logic isolated from business logic
- Use type-safe SQL with `dream_sql_generator`

**Views:**
- Pure functions with no side effects
- Accept domain types, return strings
- Handle multiple formats (JSON, HTML, CSV) in the same view module
- Compose templates for reusable HTML components

For detailed patterns and examples, see:
- [Build a database-backed JSON API](../guides/database-api.md) - Detailed MVC patterns
- [Move a workflow into an operation](../guides/database-api.md#step-13-move-a-workflow-into-an-operation) - Complex business logic
- [Render HTML and other formats](../guides/templates.md) - Content negotiation

## Design Decisions

### Why No Global Middleware?

Middleware is explicit per route. This makes it obvious which middleware runs on which route. No hunting through files to find what's running.

### Why Separate Context and Services?

- **Context** - Mutable, per-request data (user, request ID)
- **Services** - Immutable, application-level (database, config)

Separating them makes the distinction clear.

### Why No Closures?

Closures hide dependencies. Explicit parameters make dependencies visible:

#### A closure versus a parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_closures.gleam#L20-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Bad: the closure hides the database
pub fn create_handler(
  database: Database,
) -> fn(Request, EmptyContext, EmptyServices) -> Response {
  fn(_request, _context, _services) { count_users(database) }
}

// Good: the database comes in as a parameter
pub fn handle_request(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let database = services.database
  count_users(database)
}
```

`create_handler` returns a controller that holds the database, but the controller's type does not show it. `handle_request` gets the database from `Services`, so its signature shows where the data comes from.

The same rule applies to WebSocket handlers: instead of capturing services in
closures, bundle them into a `Dependencies` type and pass that into
`upgrade_websocket` so each handler receives what it needs explicitly.

See the [WebSockets guide](../guides/websockets.md) for concrete patterns.

### Why Builder Pattern?

Fluent, readable, and type-safe. Each step transforms the previous value. No global state. No side effects.

## Performance

Dream runs on the BEAM. Performance characteristics:

- **Concurrent connections** - Thousands per core (BEAM is excellent at this)
- **Memory usage** - 1-2GB is normal for production apps
- **Response time** - Microseconds for routing, milliseconds for full request
- **Connection pooling** - `dream_postgres_client` handles this efficiently

The BEAM is battle-tested. It scales.

## Modules Ecosystem

Core provides routing and HTTP primitives. Other packages, such as a database client or an HTTP client, work with Dream. Each one has its own repository, its own version and its own releases, separate from Dream. The [Ecosystem](../index.md#-ecosystem) section of the documentation index lists each package with its current version.

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
- Works with SQL queries that `dream_sql_generator` generates

#### Connect and query with dream_postgres <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_postgres.gleam#L6-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_postgres/client.{
  type Config, type Connection, type QueryError, type Returned,
}
import dream_postgres/query
import dream_postgres_client
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/otp/actor

pub fn create_database_config() -> Config {
  client.new(process.new_name("app_database"))
  |> client.host("localhost")
  |> client.database("app")
  |> client.pool_size(10)
}

pub fn connect_database() -> Result(Connection, actor.StartError) {
  create_database_config()
  |> client.connect()
}

pub fn find_user_name(db: Connection, id: Int) -> String {
  dream_postgres_client.query("SELECT name FROM users WHERE id = $1")
  |> dream_postgres_client.parameter(dream_postgres_client.int(id))
  |> dream_postgres_client.returning(decode.at([0], decode.string))
  |> dream_postgres_client.execute(db)
  |> describe_user_name()
}

pub fn describe_user_name(
  result: Result(Returned(String), QueryError),
) -> String {
  case query.first_row(result) {
    Ok(name) -> name
    Error(query.NotFound) -> "No such user"
    Error(query.DatabaseError) -> "The database query failed"
  }
}
```

`client.from_url` also exists. It reads the same settings from a connection URL, and it also returns a `Result` that you can handle.

**`dream_opensearch`** - OpenSearch client
- Document indexing and search
- Query builders (match_all, term, match)
- HTTP wrapper for OpenSearch API

#### Index a document with dream_opensearch <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_opensearch.gleam#L5-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn create_client() -> Client {
  client.new("http://localhost:9200")
}

pub fn index_log_entry(
  opensearch: Client,
  message: String,
) -> Result(String, String) {
  let document_json =
    json.object([#("message", json.string(message))])
    |> json.to_string()
  document.index(opensearch, "logs", "doc-id-123", document_json)
}
```

### Utility Modules

**`dream_http_client`** - HTTP client with three execution modes
- **Blocking** (`send`) - Complete response at once (JSON APIs)
- **Yielder streaming** (`stream_yielder`) - Sequential chunks (AI responses, file downloads)
- **Process-based streaming** (`start_stream`) - Non-blocking streams with callbacks
- HTTPS support, configurable timeouts, builder pattern
- Built on Erlang's battle-tested `httpc`

#### Build and send a request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_builders.gleam#L54-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// HTTP client
pub fn create_users_request() -> ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.timeout(5000)
}

pub fn fetch_users() -> Result(HttpResponse, SendError) {
  create_users_request()
  |> client.send()
}
```

Each builder step returns a new request. `client.send()` sends it and returns `Result(HttpResponse, SendError)`. For streaming, see `stream_yielder` and `start_stream` in the module docs.

**`dream_config`** - Configuration management
- Environment variable loading
- .env file support
- Type-safe configuration loading

#### Load configuration with dream_config <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_config.gleam#L6-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_config/loader
import gleam/result

pub type AppConfig {
  AppConfig(database_url: String, port: Int)
}

pub fn load_config() -> Result(AppConfig, String) {
  use _ <- result.try(
    loader.load_dotenv() |> result.map_error(loader.describe_load_error),
  )
  use database_url <- result.try(
    loader.get_required("DATABASE_URL") |> result.map_error(loader.describe),
  )
  let port = loader.get_int("PORT") |> result.unwrap(3000)
  Ok(AppConfig(database_url: database_url, port: port))
}
```

**`dream_json`** - JSON encoding utilities
- JSON encoders for optional values and timestamps
- Convenience functions for common JSON encoding patterns

#### Encode optional fields with dream_json <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/architecture_json.gleam#L5-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_json/json_encoders
import gleam/json
import gleam/option.{type Option}

pub type Profile {
  Profile(email: Option(String), age: Option(Int))
}

pub fn profile_to_json(profile: Profile) -> String {
  json.object([
    #("email", json_encoders.optional_string(profile.email)),
    #("age", json_encoders.optional_int(profile.age)),
  ])
  |> json.to_string()
}
```

**`dream_ets`** - ETS (Erlang Term Storage) utilities
- In-memory key-value storage
- Process-safe table operations
- Useful for caching, rate limiting, and shared state

### Using Modules

Modules are independent Gleam packages on Hex. Add the ones you need next to `dream`:

```toml
[dependencies]
dream = ">= 3.0.0 and < 4.0.0"
```

The `database` example adds `dream_postgres` and `dream_postgres_client` next to `dream`. This is its `dream_postgres_client` line:

#### dream_postgres_client in the database example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/gleam.toml#L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_postgres_client = ">= 1.0.0 and < 2.0.0"
```

Each module has its own repository, with a README that has detailed usage examples: [dream_config](https://github.com/TrustBound/dream_config), [dream_ets](https://github.com/TrustBound/dream_ets), [dream_http_client](https://github.com/TrustBound/dream_http_client), [dream_json](https://github.com/TrustBound/dream_json), [dream_mock_server](https://github.com/TrustBound/dream_mock_server), [dream_opensearch](https://github.com/TrustBound/dream_opensearch) and [dream_postgres](https://github.com/TrustBound/dream_postgres).

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
- [Build a database-backed JSON API](../guides/database-api.md) - Models, views, controllers in practice
- [Route requests and add middleware](../guides/routing.md) - Middleware in depth

---

**See Also:**
- [Design Principles](design-principles.md) - Why Dream is built this way
- [Dream vs Mist](dream-vs-mist.md) - What Dream adds over raw Mist

