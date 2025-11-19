# Dream Architecture Instructions for AI Assistant

This file contains instructions for the AI assistant on how to create proper plans for Dream changes. It documents all architectural patterns, code standards, and separation of concerns principles.

---

## Dream Patterns Overview

Dream uses the following patterns with specific purposes:

### 1. Builder Pattern
Configuring complex objects step-by-step.

**Example:**
```gleam
// PostgreSQL connection
postgres.new()
|> postgres.host("localhost")
|> postgres.port(5432)
|> postgres.database("mydb")
|> postgres.user("user")
|> postgres.password("pass")
|> postgres.connect()

// HTTP client
client.new()
|> client.method(http.Get)
|> client.scheme(http.Https)
|> client.host("api.example.com")
|> client.path("/users")
|> client.fetch()
```

### 2. Dependency Injection Pattern
Pass dependencies explicitly as parameters, no globals or singletons.

**Example:**
```gleam
// Bad - Global database connection
// pub const global_db = connect_db()  // ❌ Don't do this

// Good - Pass dependencies as parameters
pub fn get_user(db: pog.Connection, id: Int) -> Result(User, DataError) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(err) -> Error(DatabaseError(err))
  }
}

pub fn send_email(
  http_client: http_client.Client,
  to: String,
  subject: String,
  body: String,
) -> Result(Nil, EmailError) {
  http_client
  |> client.method(http.Post)
  |> client.host("api.sendgrid.com")
  |> client.path("/v3/mail/send")
  |> client.body(email_json(to, subject, body))
  |> client.fetch()
}

// Controllers receive dependencies
pub fn show(request: Request, context: Context, services: Services) -> Response {
  let assert Ok(id_param) = get_param(request, "id")
  let assert Ok(id) = id_param.as_int
  
  // Inject db from services
  case get_user(services.db, id) {
    Ok(user) -> json_response(status.ok, user_to_json(user))
    Error(_) -> json_response(status.not_found, error_json("Not found"))
  }
}
```

### 3. Middleware Pattern
Wrap controllers to add cross-cutting behavior.

**Example:**
```gleam
pub fn logging_middleware(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  let start = monotonic_time()
  
  // Call next middleware/controller
  let response = next(request, context, services)
  
  let duration = monotonic_time() - start
  log_request(request.path, response.status, duration)
  
  response
}

// Use in router
Route(
  method: Get,
  path: "/api/users",
  controller: users_controller.list,
  middleware: [logging_middleware, auth_middleware],
)
```

### 4. Model Pattern
Data access layer, handles persistence.

**Example:**
```gleam
// models/user/user.gleam
import user/sql
import pog

pub fn get(db: pog.Connection, id: Int) -> Result(User, DataError) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(err) -> Error(DatabaseError(err))
  }
}

pub fn list(db: pog.Connection) -> Result(List(User), DataError) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(list.map(returned.rows, row_to_user))
    Error(err) -> Error(DatabaseError(err))
  }
}

pub fn create(db: pog.Connection, data: UserData) -> Result(User, DataError) {
  case sql.create_user(db, data.email, data.name) {
    Ok(returned) -> extract_first_user(returned)
    Error(err) -> Error(DatabaseError(err))
  }
}

fn extract_first_user(returned: pog.Returned(sql.GetUserRow)) -> Result(User, DataError) {
  case list.first(returned.rows) {
    Ok(row) -> Ok(row_to_user(row))
    Error(_) -> Error(NotFound)
  }
}

// Convert Squirrel row to domain type
fn row_to_user(row: sql.GetUserRow) -> User {
  User(
    id: row.id,
    email: row.email,
    name: row.name,
    created_at: row.created_at,
  )
}
```

### 5. Services Pattern
External connections and clients.

**Example:**
```gleam
// services.gleam
pub type Services {
  Services(
    db: pog.Connection,
    opensearch: opensearch.Client,
    http_client: http_client.Client,
    events: events_service.EventsService,
  )
}

pub fn initialize_services() -> Services {
  Services(
    db: connect_db(),
    opensearch: connect_opensearch(),
    http_client: http_client.new(),
    events: events_service.start(),
  )
}
```

### 6. Controller Pattern
HTTP handlers that orchestrate request → response.

**Example:**
```gleam
// controllers/users_controller.gleam
pub fn show(request: Request, context: Context, services: Services) -> Response {
  case get_param(request, "id") {
    Ok(param) -> show_with_id(services, param)
    Error(_) -> json_response(status.bad_request, error_json("Invalid ID"))
  }
}

fn show_with_id(services: Services, param: PathParam) -> Response {
  case param.as_int {
    Ok(id) -> show_user(services, id, param)
    Error(_) -> json_response(status.bad_request, error_json("ID must be integer"))
  }
}

fn show_user(services: Services, id: Int, param: PathParam) -> Response {
  case user_model.get(services.db, id) {
    Ok(user) -> user_view.respond(user, param)
    Error(_) -> json_response(status.not_found, error_json("User not found"))
  }
}
```

### 7. Operation Pattern
Complex business logic coordinating multiple services.

**Example:**
```gleam
// operations/publish_post.gleam
pub fn execute(
  services: Services,
  post_id: Int,
) -> Result(Post, OperationError) {
  use post <- result.try(post_model.get(services.db, post_id))
  
  // Update status in database
  use published_post <- result.try(
    post_model.update_status(services.db, post_id, Published)
  )
  
  // Index in OpenSearch
  let _ = post_model.index(services.opensearch, published_post)
  
  // Broadcast event
  let event = Event(
    event_type: PostPublished,
    post_id: Some(post_id),
    timestamp: now(),
  )
  events_service.broadcast(services.events, event)
  
  Ok(published_post)
}
```

### 8. View Pattern
Presentation layer, formats domain types.

**Example:**
```gleam
// views/user_view.gleam
pub fn respond(user: User, param: PathParam) -> Response {
  case param.format {
    Some("json") -> json_response(status.ok, to_json(user))
    Some("csv") -> text_response(status.ok, to_csv(user))
    _ -> html_response(status.ok, to_html(user))
  }
}

pub fn to_json(user: User) -> String {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("name", json.string(user.name)),
  ])
  |> json.to_string()
}

pub fn to_csv(user: User) -> String {
  int.to_string(user.id) <> "," <> user.email <> "," <> user.name
}

pub fn to_html(user: User) -> String {
  "<div><h1>" <> user.name <> "</h1><p>" <> user.email <> "</p></div>"
}
```

### 9. Context Pattern
Per-request data that changes with each request.

**Example:**
```gleam
// context.gleam
pub type Context {
  Context(
    request_id: String,
    user: option.Option(User),
    session: option.Option(Session),
  )
}

// Created per request
pub fn new_context() -> Context {
  Context(
    request_id: generate_request_id(),
    user: option.None,
    session: option.None,
  )
}

// Enriched by middleware
pub fn auth_middleware(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case extract_token(request) {
    Ok(token) -> verify_and_enrich(request, context, services, next, token)
    Error(_) -> json_response(status.unauthorized, error_json("Missing token"))
  }
}

fn verify_and_enrich(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
  token: String,
) -> Response {
  case verify_token(services.db, token) {
    Ok(user) -> {
      let enriched_context = Context(..context, user: option.Some(user))
      next(request, enriched_context, services)
    }
    Error(_) -> json_response(status.unauthorized, error_json("Invalid token"))
  }
}
```

---

## 1. Dream Philosophy

- **Minimal core, explicit dependencies, no magic** - Everything is visible in your code, no hidden behavior
- **Transferable knowledge over framework-specific patterns** - Learn fundamental concepts, not Dream-specific solutions
- **Small, isolated modules with single concerns** - Each module does one thing well

---

## 2. Architecture Layers

### Models (Repositories)
Data access layer that handles persistence.

- Take connections as parameters (explicit dependencies)
- Return domain types (not DB types)
- Handle DB ↔ Domain conversion internally
- Example: `user.get(db, id) -> Result(User, DataError)`

### Views (Serializers)
Presentation layer that formats data.

- Pure formatting functions
- Take domain types, return strings (JSON, HTML, CSV, etc.)
- No Result types, no HTTP knowledge
- Example: `user_view.to_json(user) -> String`

### Controllers (HTTP Handlers)
HTTP request/response layer.

- Parse requests, extract parameters
- Call models/operations
- Map errors to status codes
- Call views for formatting, build responses
- Pattern: Request → Model → View → Response

### Operations (Business Logic)
Orchestration layer for complex workflows.

- Orchestrate multiple models
- Enforce business rules
- Coordinate cross-service side effects
- Example: `publish_post.execute()` updates DB + OpenSearch + broadcasts event

### Services (External Dependencies)
External connections and clients.

- Just connections and clients
- No business logic, pure dependencies
- Example: `Services(db: Connection, opensearch: Client)`

### Middleware
Request/response wrappers.

- Functions that wrap controllers
- Signature: `fn(Request, Context, Services, next) -> Response`
- Can modify request going in, response coming out
- Use for cross-cutting concerns (logging, auth)

### Context
Per-request data.

- Per-request data (user info, request_id, session)
- Changes per request
- Different from Services (which are shared across all requests)

---

## 3. Core vs Helpers vs Modules

### Core (`src/dream/`)
Essential HTTP primitives and routing.

**Contains:**
- HTTP primitives: Request, Response, Header, Cookie types
- Router: Pattern matching, parameter extraction
- Response builders: `json_response(Int, String)`, `html_response()`, etc.
- Status constants: `ok = 200`, `not_found = 404`, etc.
- Validation: `validate_json()` returns `Result(T, ValidationError)`
- Server integration (Mist)

**Core uses Int for status codes:**
```gleam
Response(
  status: 200,  // Raw Int
  body: Text("Hello"),
  headers: [Header("Content-Type", "text/plain")],
  cookies: [],
  content_type: Some("text/plain"),
)
```

### Helpers (`modules/helpers/`)
Optional convenience utilities.

- JSON encoders for optional values
- May become obsolete as they get moved to core

### Modules (`modules/*/`)
Independent Gleam packages.

- Own gleam.toml, Makefile, tests, README
- Current modules: dream_postgres, dream_http_client, dream_opensearch, dream_config, dream_ets, dream_helpers

---

## 4. Separation of Concerns

### Validation is NOT Coupled to Responses

Keep validation and response building separate:

- **Validation:** String + Decoder → Result(T, ValidationError)
- **Responses:** Status + body → Response
- **Controllers connect them explicitly**

Example:
```gleam
case validate_json(request.body, decoder) {
  Ok(data) -> create_with_data(services, data)
  Error(err) -> json_response(status.bad_request, error_json(err))
}
```

### Response Builders in Core

Response builders are universal needs, not opinionated convenience.

- Accept Int for status (not elaborate Status types)
- Construct proper headers, content-type
- Every app needs these

### Status Codes

Keep status codes simple.

- Core uses Int (200, 404, 500)
- Core provides constants (status.ok, status.not_found)
- No elaborate type hierarchy (no Status types with descriptions)

---

## 5. Code Style Standards

### No Nested Case Statements

Extract helper functions to avoid nesting.

**Bad:**
```gleam
case validate(...) {
  Ok(data) -> case model.create(...) {
    Ok(result) -> ...
  }
}
```

**Good:**
```gleam
pub fn create(request, context, services) -> Response {
  case validate_json(request.body, decoder) {
    Ok(data) -> create_with_data(services, data)
    Error(err) -> json_response(status.bad_request, error_json(err))
  }
}

fn create_with_data(services, data) -> Response {
  case model.create(services.db, data) {
    Ok(result) -> json_response(status.created, to_json(result))
    Error(_) -> json_response(status.internal_server_error, error_json())
  }
}
```

### No Anonymous Functions

All functions should be explicitly named.

- Extract helper functions instead of inline lambdas
- Makes code easier to test and understand

### Use Assert Pattern for get_param

Use `let assert Ok(...)` for extracting path parameters to keep controllers clean.

**Bad:**
```gleam
pub fn show(request: Request, context: Context, services: Services) -> Response {
  case get_param(request, "id") {
    Ok(param) -> show_with_id(services, param)
    Error(_) -> errors.bad_request("Invalid ID parameter")
  }
}

fn show_with_id(services: Services, param: PathParam) -> Response {
  case param.as_int {
    Ok(id) -> show_user(services, id)
    Error(_) -> errors.bad_request("ID must be an integer")
  }
}

fn show_user(services: Services, id: Int) -> Response {
  // ... actual logic
}
```

**Good:**
```gleam
pub fn show(request: Request, context: Context, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  // ... actual logic
}
```

**Why it's safe:**

1. **Router guarantees:** The router only matches routes when path parameters exist. If a route like `/users/:id` matches, the `id` parameter is guaranteed to be present.

2. **Type safety:** Gleam's assert pattern will crash at runtime if the value is `Error`, which is appropriate for invalid route matches (a programming error, not a user error).

3. **Cleaner code:** Eliminates unnecessary helper functions and case statements for parameter extraction, making controllers more readable.

4. **Consistent pattern:** All controllers use the same pattern, making the codebase easier to understand.

**Note:** This pattern is specifically for path parameters extracted by the router. For query parameters or request body validation, use proper `case` statements with error handling, as those can legitimately be missing or invalid.

---

## 6. Module Organization

Each module must have:

- `gleam.toml` with dependencies
- `Makefile` with targets: test, clean, build, format, docs, check
- `README.md` with usage examples
- Comprehensive test coverage
- Tests following naming convention: `<function>_<condition>_<result>_test()`

---

## 7. Testing Standards

Follow `docs/guides/testing.md`:

- **AAA pattern:** Arrange, Act, Assert (with blank lines between sections)
- **Black box testing:** Public interfaces only
- **Unit tests:** Isolated, fast, deterministic
- **Entry point:** `pub fn main() { gleeunit.main() }`
- **Naming:** `function_condition_result_test()`

Example:
```gleam
pub fn validate_json_with_valid_data_returns_decoded_data_test() {
  // Arrange
  let body = "{\"name\": \"John\"}"
  let decoder = user_decoder()

  // Act
  let result = validate_json(body, decoder)

  // Assert
  assert Ok(user) = result
  assert user.name == "John"
}
```

---

## 8. File Structure Conventions

### Application Structure

```
src/
├── main.gleam          # Server setup
├── router.gleam        # Route definitions
├── context.gleam       # Request context type
├── services.gleam      # External dependencies type
├── types/              # Domain types
├── models/             # Data repositories
│   └── entity/
│       ├── entity.gleam
│       ├── sql.gleam   # Squirrel-generated
│       └── sql/*.sql
├── views/              # Serializers
├── controllers/        # HTTP handlers
├── operations/         # Business logic
└── middleware/         # Request/response wrappers
```

### Core Structure

```
src/dream/
├── context.gleam               # AppContext
├── dream.gleam                 # Core exports
├── router.gleam                # Route matching
├── http/
│   ├── transaction.gleam       # Request/Response types
│   ├── response.gleam          # Response builders
│   ├── status.gleam            # Status constants
│   └── validation.gleam        # JSON validation
├── servers/
│   └── mist/                   # Mist integration
└── controllers/
    └── static.gleam            # Static file serving
```

---

## 9. When to Use Each Pattern

### Use Controllers for:
- Simple CRUD operations
- Single-model operations
- Direct request → model → view flow

Example: `users_controller.gleam` with get, list, create, update, delete

### Use Operations for:
- Multi-service coordination
- Complex business rules
- Cross-cutting concerns

Example: `publish_post.execute()` that:
- Updates post status in database
- Indexes post in OpenSearch
- Broadcasts event via SSE

### Use Middleware for:
- Cross-cutting concerns (logging, auth)
- Request/response modification
- Should NOT contain business logic

Example: `logging_middleware.gleam` that logs requests to OpenSearch

---

## 10. Import Patterns

### Prefer Explicit Imports

```gleam
import dream/http/transaction.{type Request, type Response}
import dream/http/response.{json_response, html_response}
import dream/http/status
import dream/router.{type Router, route}
import dream/context.{type AppContext}

// Usage
json_response(status.ok, body)
```

### Avoid
- Wildcard imports
- Unnecessary aliases
- Importing everything from a module

---

## 11. Error Handling

### Domain Errors

Define domain-specific error types:

```gleam
pub type UserError {
  EmailAlreadyExists(email: String)
  WeakPassword
  InvalidEmail(email: String)
  UserNotFound(id: Int)
}
```

### Map to HTTP Status Codes in Controllers

```gleam
case user_model.create(services.db, data) {
  Ok(user) -> json_response(status.created, user_to_json(user))
  Error(EmailAlreadyExists(email)) -> 
    json_response(status.conflict, error_json("Email already exists"))
  Error(WeakPassword) -> 
    json_response(status.unprocessable_content, error_json("Weak password"))
  Error(_) -> 
    json_response(status.internal_server_error, error_json("Server error"))
}
```

### Never Auto-Generate User Errors

Don't expose internal error details to users. Always create user-friendly messages in controllers.

---

## Summary

When creating plans for Dream changes:

1. **Respect separation of concerns** - Validation ≠ Responses, Models ≠ Views
2. **Keep modules small and focused** - One concern per module
3. **No nested cases, no anonymous functions** - Extract helper functions
4. **Use assert pattern for get_param** - Router guarantees path parameters exist
5. **Core is minimal** - Only essential HTTP primitives
6. **Status codes are Ints** - No elaborate type hierarchies
7. **Be explicit** - No magic, no hidden behavior
8. **Follow the layered architecture** - Models → Controllers → Views, Operations for complex workflows
