# Dream patterns: quick guide for agents

This document explains the core architectural pieces in a typical Dream app and how agents should use them.

The main layers are:

- **Router** – maps HTTP requests to controllers.
- **Controller** – HTTP entrypoint, translates requests to domain calls and responses.
- **Middleware** – cross-cutting behavior that wraps controllers (auth, logging, rate limiting).
- **Operations** – reusable business workflows.
- **Services** – long-lived dependencies (DB pools, HTTP clients, config, broadcasters, etc.).
- **Views** – format domain data as strings (HTML, JSON, etc.).
- **Templates** – reusable building blocks for views, usually for server-side rendering.

Keep responsibilities narrow and avoid leaking concerns between layers.

---

## Router

**What it is**

- A declarative list of routes: HTTP method + path pattern + controller + middleware.

**Use the router for**

- Defining the public HTTP surface of the app.
- Attaching middleware that should always run for a given route.
- Simple parameter extraction (path segments), leaving real validation to controllers.

**Do not use the router for**

- Business logic or data access.
- Formatting responses.
- Cross-cutting concerns that depend on application state (those belong in middleware or services).

**Agent guidance**

- When adding a new feature, first ask: *What is the URL and HTTP method?* Then add a route pointing to a new or existing controller.

**Example (`examples/simple/src/router.gleam`)**

```gleam
import controllers/posts_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/",
    controller: posts_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    controller: posts_controller.show,
    middleware: [],
  )
}
```

---

## Controllers

**What they are**

- Pure HTTP handlers: `Request + Context + Services -> Response` (conceptually).
- The glue between transport (HTTP) and domain logic (operations, services, views).

**Use controllers for**

- Parsing and validating request data (params, query, body, headers, cookies).
- Translating validation errors into HTTP errors (400, 401, 404, 422, etc.).
- Calling operations and services to perform work.
- Choosing which view/template to use and which HTTP status to return.

**Do not use controllers for**

- Complex business workflows that might be reused elsewhere (CLIs, jobs).
- Direct SQL/driver calls when there is or should be a dedicated service/operation.
- Holding long-lived state.

**Agent guidance**

- Keep controllers thin: parse input, call an operation/service, render the result.
- If a controller grows large or is needed from non-HTTP contexts, extract an operation.

**Example (`examples/simple/src/controllers/posts_controller.gleam`)**

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import views/post_view

pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, post_view.format_index())
}
```

---

## Operations

**What they are**

- Functions that implement non-trivial business workflows.
- Orchestrate calls to services and enforce domain rules.

**Use operations for**

- Multi-step workflows (e.g. create record → send email → enqueue job).
- Logic that must be reused from controllers, background jobs, and tests.
- Encapsulating invariants and error handling around domain actions.

**Do not use operations for**

- HTTP-specific details (status codes, headers, cookies).
- Low-level persistence details that belong to repository-style services.

**Agent guidance**

- When logic feels “businessy” and is used from more than one place, put it in an operation.
- Have operations return domain types and error values; let controllers map those to HTTP.

**Example (`examples/database/src/operations/post_operations.gleam`)**

```gleam
import dream/http/error.{type Error}
import models/post as post_model
import pog.{type Connection}
import types/post.{type Post}

pub fn get_post(db: Connection, id: Int) -> Result(Post, Error) {
  post_model.get(db, id)
}
```

---

## Services

**What they are**

- Long-lived, application-wide dependencies, created at startup and passed explicitly.
- Examples: database pools, HTTP clients, caches, broadcasters, configuration, clock.

**Use services for**

- Anything that talks to the outside world (DB, network, filesystem, queues).
- Shared state that outlives a single request.
- Abstractions over third-party libraries.

**Do not use services for**

- Per-request data (that belongs in the Context).
- Pure computations (those can be plain functions or operations).
- Hidden globals or singletons accessed implicitly.

**Agent guidance**

- Prefer injecting services through `Services` instead of capturing them in closures.
- When adding a new external dependency, define a clear service API and thread it through.

**Example (`examples/database/src/services.gleam`)**

```gleam
import database.{type DatabaseService}

pub type Services {
  Services(database: DatabaseService)
}

pub fn initialize_services() -> Services {
  let assert Ok(database_service) = database.init_database()
  Services(database: database_service)
}
```

---

## Middleware

**What it is**

- Functions that wrap controllers for cross-cutting concerns.
- Signature conceptually: `fn(Request, Context, Services, Next) -> Response`, where `Next` is the rest of the chain.

**Use middleware for**

- Authentication and authorization gates.
- Logging, metrics, tracing.
- Rate limiting, CSRF checks, request/response mutation.

**Do not use middleware for**

- Core business workflows (those belong in operations).
- Direct data access that should live in models/services.
- Long-lived state (that belongs in services).

**Agent guidance**

- Keep middleware small and focused on a single concern.
- Always pass `request`, `context`, and `services` explicitly; never capture services in closures.
- When multiple routes share the same cross-cutting behavior, prefer middleware over copy-pasting logic into controllers.

**Example (`examples/custom_context/src/middleware/auth_middleware.gleam`)**

```gleam
import context.{type AuthContext}
import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/option
import services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Missing Authorization header")
    option.Some(token) ->
      validate_and_authenticate(request, context, services, token, next)
  }
}
```

---

## Views

**What they are**

- Pure formatting functions that take domain types and return rendered content (strings or serializable structures).
- Do not know about HTTP, databases, or other side effects.

**Use views for**

- Converting domain results into HTML, JSON, CSV, text, etc.
- Keeping formatting concerns separate from controllers and operations.
- Sharing presentation logic between different controllers or endpoints.

**Do not use views for**

- Business decisions (authorization, validation, branching on complex domain rules).
- Performing I/O or reading from services.

**Agent guidance**

- If the only responsibility is “turn this domain value into a response body,” it probably belongs in a view.

**Example (`examples/database/src/views/post_view.gleam`)**

```gleam
import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import types/post.{type Post}

pub fn to_json(post: Post) -> String {
  json.object([
    #("id", json.int(post.id)),
    #("user_id", json.int(post.user_id)),
    #("title", json.string(post.title)),
    #("content", encoders.optional_string(post.content)),
    #("created_at", encoders.timestamp(option.Some(post.created_at))),
  ])
  |> json.to_string()
}
```

---

## Templates

**What they are**

- Reusable view components (page layouts, partials, HTML elements, email fragments).
- Typically composed by view functions.

**Use templates for**

- Sharing layout and markup across pages and responses.
- Managing complex server-side rendering while keeping pieces small and testable.

**Do not use templates for**

- Calling services or operations.
- Encoding core business rules.

**Agent guidance**

- Think of templates as building blocks; views assemble them, controllers choose which view to use.

**Example (`examples/tasks/src/views/task_view.gleam`)**

```gleam
import templates/components/layout_components
import templates/components/task_components
import templates/pages/index
import types/tag.{type Tag}
import types/task.{type Task}

pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let list = task_components.task_list(tasks, tags_by_task)
  let content = index.render(task_list: list)
  layout_components.build_page("Tasks", content)
}
```

---

## When to choose which layer

- **New endpoint for existing behavior**: add a router entry and a small controller that calls an existing operation or service, then reuse existing views/templates.
- **New business workflow**: create or update an operation; wire it into one or more controllers; keep views/templates focused on rendering the results.
- **New integration (DB, API, queue)**: design a service that wraps the external system; call it from operations; never from templates or views.
- **New presentation or format**: add/extend views and templates; reuse existing operations and services unchanged.

If you are unsure where code belongs, default to:

1. Put external effects in **services**.
2. Put business rules in **operations**.
3. Keep **controllers** thin and HTTP-focused.
4. Keep **views/templates** pure and presentation-focused.

---

## Recommended project structure

Agents should assume a "typical" Dream app is organized roughly like this when creating or moving files:

```text
src/
  main.gleam          # Application entry point (server setup)
  router.gleam        # Route definitions
  services.gleam      # Top-level Services type and initializers
  context.gleam       # Context type(s) for per-request data
  config.gleam        # Configuration loading helpers

  controllers/        # HTTP controllers (public actions)
    users_controller.gleam
    posts_controller.gleam

  middleware/         # Cross-cutting concerns
    auth_middleware.gleam
    logging_middleware.gleam

  models/             # Data access layer (DB, external systems)
    user/
      user_model.gleam
      sql.gleam       # Squirrel-generated SQL (if used)
    post/
      post_model.gleam
      sql.gleam

  views/              # Response formatting / presenters
    user_view.gleam
    post_view.gleam

  operations/         # Complex business workflows
    publish_post.gleam

  templates/          # SSR templates (optional)
    elements/
    components/
    layouts/
    pages/

  services/           # Service-specific setup helpers
    database.gleam

  types/              # Shared domain types
    user.gleam
```

**Agent guidance**

- When adding a new endpoint:
  - Controller code goes in `controllers/*_controller.gleam`.
  - New business workflows go in `operations/`.
  - New DB access logic goes in `models/`.
  - New response formatting goes in `views/` (and optionally `templates/`).
- When adding a new cross-cutting concern (auth, logging, rate limiting):
  - Prefer `middleware/` + possibly new fields on `Services` or `Context`.
- When introducing a new external system (queue, cache, third-party API):
  - Add a clear service in `services/` (and a field on `Services`), then call it from operations/controllers.

This layout is a guideline, not a hard requirement, but agents should default to it unless the repository clearly documents a different structure.
