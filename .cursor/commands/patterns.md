# Dream Patterns and Directory Structure

This document explains when to use which patterns and where to put code in a Dream application.

## Directory Structure

Here's the recommended structure for a Dream application:

```
your_app/
├── src/
│   ├── main.gleam          # Application entry point
│   ├── router.gleam        # Route definitions
│   ├── services.gleam      # Services type definition
│   ├── context.gleam       # Per-request context types
│   ├── config.gleam        # Configuration loading
│   │
│   ├── controllers/        # Request handlers
│   ├── middleware/         # Cross-cutting concerns
│   ├── models/             # Data access layer
│   ├── views/              # Response formatting
│   ├── operations/         # Complex business logic
│   ├── templates/          # HTML templates (optional)
│   ├── services/           # Service initialization
│   ├── types/              # Domain types
│   └── utilities/          # Helper functions
│
└── gleam.toml
```

## Root-Level Files

### `main.gleam`
**Purpose:** Application entry point that sets up the server, initializes services, creates the router, and starts listening.

**Contains:**
- Server initialization
- Services initialization
- Router creation
- Server startup (`listen()`)

**Example:**
```gleam
import dream
import services
import router

pub fn main() {
  dream.new()
  |> services(services.initialize())
  |> router(router.create())
  |> bind("localhost")
  |> listen(3000)
}
```

### `router.gleam`
**Purpose:** Defines all routes: which paths map to which controllers, and what middleware to run.

**Contains:**
- Route definitions
- Middleware assignments per route
- Route grouping/organization

**Example:**
```gleam
import dream/router
import controllers/users_controller
import middleware/auth_middleware

pub fn create() -> Router {
  router()
  |> route(method: Get, path: "/users", controller: users_controller.index, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: users_controller.show, middleware: [])
  |> route(method: Post, path: "/users", controller: users_controller.create, middleware: [auth_middleware.require_auth])
}
```

### `services.gleam`
**Purpose:** Defines the Services type that holds all application-level dependencies.

**Contains:**
- Services type definition
- All shared dependencies (database, cache, HTTP clients, etc.)

**Example:**
```gleam
import dream_postgres/client.{type Connection}

pub type Services {
  Services(
    database: Connection,
    cache: ets.Table,
    http_client: dream_http_client.Client,
  )
}
```

### `context.gleam`
**Purpose:** Defines per-request context types that hold request-specific data.

**Contains:**
- Context type definitions
- Context helper functions

**Example:**
```gleam
pub type AuthContext {
  AuthContext(
    request_id: String,
    user_id: Option(Int),
    is_admin: Bool,
  )
}
```

### `config.gleam`
**Purpose:** Configuration loading and environment variable handling.

**Contains:**
- Configuration type definitions
- Environment variable parsing
- Default values

**Example:**
```gleam
pub type Config {
  Config(
    database_url: String,
    port: Int,
    environment: String,
  )
}

pub fn load() -> Config {
  Config(
    database_url: os.get_env("DATABASE_URL") |> option.unwrap("postgres://localhost/db"),
    port: os.get_env("PORT") |> option.map(int.parse) |> option.unwrap(Ok(3000)) |> result.unwrap,
    environment: os.get_env("ENV") |> option.unwrap("development"),
  )
}
```

## Directory Patterns

### `controllers/` - Request Handlers

**Purpose:** Functions that handle HTTP requests. They extract parameters, call models/operations, call views, and return responses.

**When to use:**
- ✅ Handling HTTP requests
- ✅ Extracting and validating request parameters
- ✅ Coordinating between models, operations, and views
- ✅ Returning HTTP responses

**When NOT to use:**
- ❌ Complex business logic (use operations)
- ❌ Data access (use models)
- ❌ Response formatting (use views)

**Structure:**
```
controllers/
├── users_controller.gleam
├── tasks_controller.gleam
└── projects_controller.gleam
```

**Example:**
```gleam
import dream/http.{require_int, type Request, type Response, ok}
import models/user/user_model
import views/user_view
import utilities/response_helpers

pub fn show(request: Request, context: Context, services: Services) -> Response {
  let result = {
    use user_id <- result.try(require_int(request, "id"))
    use user <- result.try(user_model.get(services.database, user_id))
    Ok(user)
  }
  
  case result {
    Ok(user) -> user_view.to_json(user) |> json_response(ok)
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

**Naming:** `{resource}_controller.gleam` (e.g., `users_controller.gleam`)

### `middleware/` - Cross-Cutting Concerns

**Purpose:** Functions that process requests/responses before/after controllers. Handle authentication, logging, rate limiting, etc.

**When to use:**
- ✅ Authentication/authorization
- ✅ Logging
- ✅ Rate limiting
- ✅ Request/response transformation
- ✅ Error handling

**Structure:**
```
middleware/
├── auth_middleware.gleam
├── logging_middleware.gleam
└── rate_limit_middleware.gleam
```

**Example:**
```gleam
import dream/http.{type Request, type Response, unauthorized}

pub fn require_auth(request: Request, context: Context, services: Services, next: fn(Request, Context, Services) -> Response) -> Response {
  case get_user_from_context(context) {
    Some(_user) -> next(request, context, services)
    None -> unauthorized()
  }
}
```

**Naming:** `{purpose}_middleware.gleam` (e.g., `auth_middleware.gleam`)

### `models/` - Data Access Layer

**Purpose:** Data access functions. They take a database connection, run queries, and return domain types.

**When to use:**
- ✅ Database queries
- ✅ Data persistence
- ✅ Data retrieval
- ✅ Type conversion from database rows to domain types

**When NOT to use:**
- ❌ Business logic (use operations)
- ❌ HTTP concerns (use controllers)
- ❌ Response formatting (use views)

**Structure:**
```
models/
├── user/
│   ├── user_model.gleam
│   └── sql/
│       ├── get_user.sql
│       ├── create_user.sql
│       └── update_user.sql
└── task/
    ├── task_model.gleam
    └── sql/
        ├── get_task.sql
        └── create_task.sql
```

**Example:**
```gleam
import dream_postgres/client.{type Connection}
import types/user.{type User}
import sql/get_user

pub fn get(db: Connection, user_id: Int) -> Result(User, Error) {
  get_user.query(db, user_id)
  |> result.map(convert_row_to_user)
}
```

**Naming:** `{resource}/` directory, `{resource}_model.gleam` file (e.g., `user/user_model.gleam`)

### `views/` - Response Formatting

**Purpose:** Formatting functions. They take domain types and return strings (JSON, HTML, CSV, etc.).

**When to use:**
- ✅ Converting domain types to JSON
- ✅ Converting domain types to HTML
- ✅ Converting domain types to CSV
- ✅ Multi-format responses (JSON + HTML from same controller)

**When NOT to use:**
- ❌ Business logic (use operations)
- ❌ Data access (use models)
- ❌ Request handling (use controllers)

**Structure:**
```
views/
├── user_view.gleam
├── task_view.gleam
└── errors.gleam
```

**Example:**
```gleam
import types/user.{type User}
import gleam/json

pub fn to_json(user: User) -> String {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("name", json.string(user.name)),
  ])
  |> json.encode
}

pub fn to_html(user: User) -> String {
  "<div><h1>" <> user.name <> "</h1><p>" <> user.email <> "</p></div>"
}
```

**Naming:** `{resource}_view.gleam` (e.g., `user_view.gleam`)

### `operations/` - Complex Business Logic

**Purpose:** Complex business logic that coordinates multiple models or services. Testable without HTTP.

**When to use:**
- ✅ Coordinating 2+ models
- ✅ Complex business rules spanning entities
- ✅ Side effects (events, emails, search indexing)
- ✅ Logic you want to test without HTTP
- ✅ Reusable business logic across multiple controllers

**When NOT to use:**
- ❌ Simple CRUD (controller → model → view is fine)
- ❌ Single model operations (use model directly)
- ❌ Pure formatting (that's a view)

**Structure:**
```
operations/
├── create_user.gleam
├── reorder_tasks.gleam
└── publish_post.gleam
```

**Example:**
```gleam
import types/user.{type User, type UserParams}
import models/user/user_model
import services.{type Services}

pub fn execute(services: Services, params: UserParams) -> Result(User, Error) {
  use _ <- result.try(validate_params(params))
  use user <- result.try(user_model.create(services.database, params))
  let _ = send_welcome_email(services.mailer, user)
  let _ = index_user(services.search, user)
  Ok(user)
}
```

**Naming:** `{action}_{resource}.gleam` or `{action}.gleam` (e.g., `create_user.gleam`, `reorder_tasks.gleam`)

**Function naming:** Operations typically have an `execute` function:
```gleam
pub fn execute(services: Services, params: Params) -> Result(ResultType, Error)
```

### `templates/` - HTML Templates (Optional)

**Purpose:** HTML templates for server-side rendering. Uses Matcha templates compiled to Gleam functions.

**When to use:**
- ✅ Server-side rendering (SSR)
- ✅ HTML responses
- ✅ Reusable HTML components

**When NOT to use:**
- ❌ API-only applications (skip templates)
- ❌ JSON-only responses (use views)

**Structure:**
```
templates/
├── elements/        # Low-level HTML elements
│   ├── button.gleam
│   ├── button.matcha
│   ├── input.gleam
│   └── input.matcha
├── components/     # Reusable UI components
│   ├── task_card.gleam
│   ├── task_card.matcha
│   └── user_form.gleam
├── layouts/        # Page layouts (nav, footer)
│   ├── page.gleam
│   ├── page.matcha
│   ├── nav.gleam
│   └── nav.matcha
└── pages/          # Full page templates
    ├── index.gleam
    ├── index.matcha
    └── user_show.gleam
```

**Layers:**
1. **Elements** (`templates/elements/`) - Low-level HTML components (buttons, inputs, etc.)
2. **Components** (`templates/components/`) - Compose elements into reusable pieces
3. **Pages** (`templates/pages/`) - Compose components into full pages
4. **Layouts** (`templates/layouts/`) - Page structure (nav, footer, main wrapper)

**Example Element:**
```matcha
{> with button_id as String
{> with button_text as String
<button id="{{ button_id }}">{{ button_text }}</button>
```

**Example Component:**
```gleam
import templates/elements/button
import types/task.{type Task}

pub fn task_card(task: Task) -> String {
  button.render(
    button_id: "task-" <> int.to_string(task.id),
    button_text: task.title
  )
}
```

**Naming:** `{name}.gleam` and `{name}.matcha` pairs (e.g., `button.gleam` and `button.matcha`)

### `services/` - Service Initialization

**Purpose:** Initialization of shared dependencies (database connections, HTTP clients, caches).

**When to use:**
- ✅ Database connection initialization
- ✅ HTTP client initialization
- ✅ Cache initialization
- ✅ External service client setup

**Structure:**
```
services/
├── database.gleam
├── cache.gleam
└── http_client.gleam
```

**Example:**
```gleam
import dream_postgres/client

pub fn init_database() -> Result(Connection, Error) {
  client.new("postgres://localhost/mydb")
}

pub fn init_cache() -> Result(ets.Table, Error) {
  ets.new()
}
```

**Naming:** `{service_name}.gleam` (e.g., `database.gleam`)

**Note:** The `services.gleam` file at the root defines the Services type. The `services/` directory contains initialization functions for individual services.

### `types/` - Domain Types

**Purpose:** Domain types that represent your business entities.

**When to use:**
- ✅ Core business entity types
- ✅ Value objects
- ✅ Domain-specific types

**Structure:**
```
types/
├── user.gleam
├── task.gleam
└── project.gleam
```

**Example:**
```gleam
pub type User {
  User(
    id: Int,
    email: String,
    name: String,
    created_at: Date,
  )
}

pub type UserParams {
  UserParams(
    email: String,
    name: String,
  )
}
```

**Naming:** `{resource}.gleam` (e.g., `user.gleam`)

### `utilities/` - Helper Functions

**Purpose:** Helper functions that don't fit into other categories.

**When to use:**
- ✅ Shared utility functions
- ✅ Response helpers
- ✅ Form parsing
- ✅ HTML helpers
- ✅ Validation helpers

**Structure:**
```
utilities/
├── response_helpers.gleam
├── form_parser.gleam
└── html_helpers.gleam
```

**Example:**
```gleam
import dream/http.{type Error, type Response, internal_server_error}

pub fn handle_error(error: Error) -> Response {
  case error {
    Error.NotFound -> not_found()
    Error.ValidationFailed(msg) -> bad_request(msg)
    _ -> internal_server_error()
  }
}
```

**Naming:** `{purpose}_helpers.gleam` or `{purpose}.gleam` (e.g., `response_helpers.gleam`)

## Pattern Decision Tree

### Where does this code go?

**Is it handling an HTTP request?**
- Yes → `controllers/`

**Is it accessing a database?**
- Yes → `models/`

**Is it formatting data for a response?**
- Yes → `views/`

**Is it complex business logic coordinating multiple things?**
- Yes → `operations/`

**Is it processing requests/responses before/after controllers?**
- Yes → `middleware/`

**Is it HTML templates?**
- Yes → `templates/`

**Is it initializing a shared dependency?**
- Yes → `services/`

**Is it a domain type?**
- Yes → `types/`

**Is it a helper function?**
- Yes → `utilities/`

## Three-Layer Architecture

Dream follows a three-layer pattern:

**Controllers** (HTTP) → **Models** (Data) → **Utilities** (Helpers)

**Controllers** handle HTTP concerns:
- Parse and validate request parameters
- Call models to fetch or update data
- Call operations for complex business logic
- Call views to format responses
- Return HTTP responses

**Models** handle data access:
- Database queries
- Data persistence
- Type conversion from database rows to domain types

**Operations** handle complex business logic:
- Coordinate multiple models
- Implement business rules
- Handle side effects

**Views** handle response formatting:
- Convert domain types to JSON, HTML, CSV, etc.
- Multi-format support

This separation keeps each layer focused. Controllers don't know about database schemas. Models don't know about HTTP status codes.

## Services vs Context

**Services** (`services.gleam`):
- Application-level, immutable
- Shared across all requests
- Examples: database connection, HTTP client, cache
- Initialized once at startup

**Context** (`context.gleam`):
- Per-request, mutable
- Changes for each request
- Examples: authenticated user, request ID, session data
- Created fresh for each request

## When to Skip Patterns

Dream doesn't enforce this structure. You can:

- ✅ Put everything in one file for simple apps (see `examples/simplest/`)
- ✅ Skip patterns you don't need (no database? Skip models)
- ✅ Organize however makes sense for your project

But this structure works. We use it in production. It scales.

## Examples

- **Simplest**: `examples/simplest/` - Everything in one file
- **Simple**: `examples/simple/` - Basic routing and HTTP client
- **Full App**: `examples/tasks/` - Complete structure with database, templates, operations

## Summary

| Directory | Purpose | When to Use |
|-----------|---------|-------------|
| `controllers/` | HTTP request handling | Handling HTTP requests, extracting parameters |
| `models/` | Data access | Database queries, data persistence |
| `views/` | Response formatting | Converting domain types to JSON/HTML/CSV |
| `operations/` | Complex business logic | Coordinating multiple models, complex rules |
| `middleware/` | Cross-cutting concerns | Auth, logging, rate limiting |
| `templates/` | HTML templates | Server-side rendering (optional) |
| `services/` | Service initialization | Database, HTTP clients, caches |
| `types/` | Domain types | Business entity types |
| `utilities/` | Helper functions | Shared utilities, response helpers |


