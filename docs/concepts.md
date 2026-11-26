# Dream Concepts

Everything you need to understand Dream. Read this, then explore the examples.

---

## Controllers

A controller is a module that contains action functions—public functions that handle HTTP requests. Each action takes a request, some context about that request, and your app's shared services (like a database connection), then returns a response.

### The controller action type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_signatures.gleam#L9-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Action =
  fn(Request, Context, Services) -> Response
```

That's it. No magic, no hidden state. The Request has the HTTP method, path, headers, and body. Context holds per-request data like the authenticated user. Services are your shared dependencies—database, cache, HTTP clients—things that don't change between requests.

Here's what a controller module (`controllers/hello_controller.gleam`) looks like with two actions:

### A controller with two actions <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_hello_controller.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_string, text_response}
import dream/http/error
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/result

pub fn greet_world(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

pub fn greet_person(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let result = {
    use name <- result.try(require_string(request, "name"))
    Ok(name)
  }

  case result {
    Ok(name) -> text_response(status.ok, "Hello, " <> name <> "!")
    Error(err) -> text_response(error.to_status_code(err), error.message(err))
  }
}
```

Actions orchestrate the request → response flow. They parse parameters, call models to fetch data, call operations for complex business logic, call views to format output, map errors to HTTP status codes, and build responses.

Use controllers for simple CRUD operations, single-model operations, or any direct request → model → view flow. Most of your endpoints will be controller actions.

**See:** [examples/database/src/controllers/](../examples/database/src/controllers/)

---

## Router

The router matches incoming requests to your controller actions based on HTTP method and path pattern. You define routes like this:

### A router <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/router.gleam#L9-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(AuthContext, Services) {
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
    middleware: [auth_middleware],
  )
  |> route(
    method: Get,
    path: "/admin",
    controller: posts_controller.index,
    middleware: [auth_middleware, admin_middleware],
  )
}
```

Path parameters like `:id` get extracted automatically. So `/users/:id/posts/:post_id` matches `/users/1/posts/2` and makes `id` and `post_id` available via `require_string(request, "id")` and `require_string(request, "post_id")`, or via `require_int` for numbers. These functions safely extract and validate parameters, returning `Result` types for error handling. `get_int_param` and `get_string_param` from `dream/http/request` do the same, but return the error as a `String`.

The router is generic over your Context and Services types. This means the compiler verifies every controller action has the right signature. Change your Context or Services type? The compiler will tell you exactly which actions need updating.

**Important Note on Parameter Type Safety:** Dream's router validates path parameters at runtime, not compile-time. If you change `/users/:id` to `/users/:user_id` in your route, but forget to update your controller code from `get_param(request, "id")` to `get_param(request, "user_id")`, the compiler won't catch this—you'll get a runtime error. This design prioritizes API ergonomics and flexibility over compile-time guarantees. We're exploring more type-safe alternatives in [Discussion #15](https://github.com/TrustBound/dream/discussions/15).

**Router Performance:** Dream uses a radix trie for O(path depth) route matching. Benchmarks show consistent ~1.3-1.5μs lookup times whether you have 100 or 1000 routes. The router is fast enough that it won't be your bottleneck.

**See:** [examples/custom_context/src/router.gleam](../examples/custom_context/src/router.gleam)

---

## Services

Your controller actions need things like database connections, HTTP clients, and caches. You could pass these through every function call, but that gets messy fast. You could use global variables, but Gleam doesn't have safe globals. You could use Erlang's process dictionary, but that's not type-safe.

Services solves this with type-safe dependency injection. You define what your app needs as fields of one type. The database example needs one service:

### The Services type <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/services.gleam#L9-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(database: DatabaseService)
}
```

Initialize it once at startup:

### Initializing services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/services.gleam#L17-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn initialize_services() -> Services {
  case database.init_database() {
    Ok(database_service) -> Services(database: database_service)
    Error(message) -> stop(message)
  }
}
```

Then give it to the server in `main`:

### Passing services to the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/main.gleam#L15-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  let assert Ok(Nil) =
    dream.new()
    |> context(db_context.context)
    |> services(initialize_services())
    |> router(create_router())
    |> bind("localhost")
    |> listen(3002)
}
```

Now every controller action gets the same Services instance. Need to add a new service? Add one field to Services, and the compiler shows you everywhere that might need it.

Yes, Services is a "god object" that holds multiple dependencies. We're okay with that tradeoff because it makes adding cross-cutting concerns easy, keeps controller action signatures consistent, and the alternative—threading dependencies through every function—is worse.

**See:** [examples/database/src/services.gleam](../examples/database/src/services.gleam)

### Builder order

Call the server builder functions in this order: `context()`, `services()`, `router()`, then `listen()`. The compiler enforces this order:

- A router's type includes the context and services types: `Router(context, services)`. Thus `context()` and `services()` accept only an app that has no router yet. If you call one of them after `router()`, the build fails with a type mismatch between `NoRouter` and `Router(...)`.
- `listen()` and `listen_with_handle()` accept only an app that has a router. If you forget `router()`, the build fails with the same type mismatch.

`bind()`, `max_body_size()` and `tls()` work before or after `router()`.

---

## Context

Context holds per-request data that changes for each request. Request A's authenticated user is different from Request B's authenticated user. That's what Context is for.

Dream provides `EmptyContext` for simple apps that don't need per-request data:

### EmptyContext <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/context.gleam#L144-L146"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type EmptyContext {
  EmptyContext
}
```

This is the default when you call `server.new()`. For apps that need request tracking, Dream also provides `AppContext`:

### AppContext <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/context.gleam#L152-L154"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type AppContext {
  AppContext(request_id: String)
}
```

But you'll probably want to add authentication with your own custom type:

### A custom AuthContext <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_context.gleam#L12-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}
```

Middleware enriches the context before it reaches controllers. Here's how an auth middleware might work:

### An auth middleware that enriches the context <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_context.gleam#L16-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn auth_middleware(request: Request, context, services, next) {
  case get_header(request.headers, "Authorization") {
    None -> unauthorized_response()
    Some(token) -> handle_token(request, context, services, next, token)
  }
}

fn handle_token(request, context, services, next, token) {
  case validate_token(token) {
    Ok(user) -> {
      // Enrich context with authenticated user
      let enriched = AuthContext(..context, user: Some(user))
      // Controller receives enriched context
      next(request, enriched, services)
    }
    Error(_) -> unauthorized_response()
  }
}
```

The controller action receives the enriched context and can access `context.user`.

**Context vs Services:**

| Context | Services |
|---------|----------|
| Per-request | Shared across all requests |
| Changes every request | Same for app lifetime |
| User, request ID | Database, cache, config |
| Middleware can modify | Initialized once at startup |

**See:** [examples/custom_context/](../examples/custom_context/)

---

## Middleware

Middleware wraps controller actions to handle cross-cutting concerns. Instead of duplicating auth checks, logging, and error handling in every action, you write it once and apply it to any route.

A middleware function has this signature:

### The middleware type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_signatures.gleam#L12-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Middleware =
  fn(Request, Context, Services, fn(Request, Context, Services) -> Response) ->
    Response
```

The fourth parameter is a function that represents the next middleware or controller action in the chain.

You get the request, context, services, and a `next` function. You can modify the request before calling `next`, enrich the context, call `next` (which passes control to the next middleware or controller action), modify the response after `next` returns, or short-circuit and return early.

Here's a logging middleware:

### A logging middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_middleware.gleam#L13-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn logging_middleware(request, context, services, next) {
  let start_time = timestamp.system_time()

  // Call next (could be another middleware or the controller action)
  let response = next(request, context, services)

  let duration = timestamp.difference(start_time, timestamp.system_time())
  log_request(request, response, duration)

  // Return (possibly modified) response
  response
}
```

Apply middleware to routes:

### Middleware on routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_middleware.gleam#L26-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(AuthContext, services) {
  router()
  // Public
  |> route(method: Get, path: "/", controller: home, middleware: [])
  |> route(method: Post, path: "/admin", controller: admin, middleware: [
    // Run first
    auth_middleware,
    // Run second
    admin_check_middleware,
    // Run third
    logging_middleware,
  ])
}
```

Execution flows like an onion:

```text illustration
Request
  → auth_middleware
    → admin_check_middleware
      → logging_middleware
        → controller action
      ← logging_middleware
    ← admin_check_middleware
  ← auth_middleware
Response
```

Use middleware for cross-cutting concerns like logging and auth, or for request/response modification. Don't put business logic in middleware—that belongs in operations or controller actions.

**See:** [examples/custom_context/src/middleware/](../examples/custom_context/src/middleware/)

---

## Operations

Sometimes a controller action must coordinate more than one model, or more than one step. That logic doesn't belong in the action.

Say the task page shows a task card. The card needs:
1. The task, from the task model
2. The task's tags, from the tag model

Extract that to an operation. The controller action stays thin, with only HTTP work:

### Controller action calls the operation <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/controllers/tasks_controller.gleam#L19-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Show single task
pub fn show(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    task_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

The operation holds the logic, with no HTTP. If the task does not exist, it returns the error. If the tags query fails, it shows the task with no tags:

### Operation coordinates two models <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/operations/task_operations.gleam#L64-L77"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Get a task with its tags
pub fn get_task_with_tags(
  db: Connection,
  task_id: Int,
) -> Result(#(Task, List(Tag)), error.Error) {
  use found <- try(get(db, task_id) |> map_error(task_error))

  let tags =
    for_task(db, found.id)
    |> map_error(tag_error)
    |> result.unwrap([])

  Ok(#(found, tags))
}
```

The operation takes a database connection and a task ID. It doesn't need a Request object. The tasks example tests it through the HTTP API, with a Cucumber scenario in [test/integration/features/tasks.feature](../examples/tasks/test/integration/features/tasks.feature):

#### The scenario <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/features/tasks.feature#L30-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
    Scenario: Get task by ID returns correct task
        Given a task exists with title "Specific Task"
        When I send a GET request to "/tasks/1"
        Then the response status should be 200
        And the response should contain "Specific Task"
```

Run `make test-integration` in `examples/tasks` to run the scenarios.

Use operations when you coordinate 2 or more models, when an action has steps that must happen in order, or when a business rule spans entities. Don't use them for simple CRUD. Most controller actions don't need operations. Only extract when the logic demands it.

**See:** [examples/tasks/src/operations/](../examples/tasks/src/operations/)

---

## Models

Models handle data access. They take a database connection (explicit dependency, no globals), run queries, and return your domain types. Controller actions call models, not SQL directly.

The examples do not write models by hand. [dream_model](https://github.com/TrustBound/dream_model) generates each model module from one `.sql` file for each query. The comment lines at the top of a file are hints:

### A query of the user model <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user/get.sql"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sql
-- returns: one User
SELECT id, name, email, created_at FROM users WHERE id = $1
```

dream_model writes `src/models/user.gleam` with a `User` record and the function `get(db, id) -> Result(User, dream_errors.Error(client.QueryError))`. The error is data, the shared error of the Dream ecosystem, with no HTTP status: with no row, `get` returns `dream_errors.NotFound`, and a database failure gives `dream_errors.Failed`. The operation calls it, and maps the error to a Dream error: its own text for a missing user, and `error.from_shared` for the rest:

### Calling the generated model <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/operations/user_operations.gleam#L16-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, error.Error) {
  get(db, id)
  |> map_error(user_error)
}
```

Models take connections as parameters and return domain types. Your controller actions stay clean: they call `user.get(db, id)` and get a `User`, not a database row. When you change a query, run `make models` to generate the module again.

**See:** [examples/database/src/models/](../examples/database/src/models/)

---

## Views

Views format domain types into strings. JSON, HTML, CSV—whatever format you need. They're pure functions: take a domain type, return a string. No Result types, no HTTP knowledge.

### A view for JSON, CSV and HTML <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_user_view.gleam#L16-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

Views are testable in isolation. Give them a `User`, get back JSON. No database, no HTTP, no mocks. Just formatting.

**See:** [examples/multi_format/src/views/](../examples/multi_format/src/views/)

### Template Composition for HTML

For server-side rendering with full type safety, Dream recommends a layered template composition approach:

1. **Elements** (`templates/elements/*.matcha`): Low-level HTML components compiled from Matcha templates
2. **Components** (`templates/components/*.gleam`): Gleam functions that compose elements into reusable pieces
3. **Pages** (`templates/pages/*.matcha` or `.gleam`): Compose components into full pages
4. **Layouts** (`templates/layouts/*.gleam`): Wrap pages with consistent structure (nav, footer, scripts)

This pattern eliminates markup duplication, keeps styling consistent, and provides full type safety through Gleam. See [Template Composition](../guides/templates.md) for a complete guide.

**See:** [examples/tasks/src/templates/](../examples/tasks/src/templates/) for a working example

---

## Separation of Concerns

Dream enforces clear boundaries between layers.

**Validation ≠ Responses**

Keep validation and response building separate. Validation takes a string and a decoder, returns `Result(T, List(ValidationError))`. Response building takes a status and body, returns a `Response`. Controllers connect them explicitly:

### Validate, then build the response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/concepts_validation.gleam#L36-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let decoder = note_decoder()
  case validate_json(body, decoder) {
    Ok(data) -> create_with_data(services, data)
    Error(err) -> json_response(status.bad_request, error_json(err))
```

**Models ≠ Views**

Models handle persistence and return domain types. Views format domain types and return strings. Controller actions orchestrate models and views. This separation makes each layer testable in isolation and keeps concerns clear.

---

## Putting It Together

When a request arrives:

```text illustration
1. Router matches path + method
2. Creates default context (or your custom context)
3. Runs middleware chain (each can enrich context)
4. Calls controller action with (Request, enriched Context, Services)
5. Action orchestrates:
   - Calls models for data access
   - Calls operations for complex logic
   - Calls views for formatting
   - Maps domain errors to HTTP status codes
6. Returns Response
```

For simple operations: `Action → Model → View → Response`

For complex operations: `Action → Operation → (Model, Model, ...) → View → Response`

No magic. No hidden configuration. Everything explicit.

The type system ensures every controller action has the correct signature, Context and Services types match across your app, the router can only route to valid actions, and the compiler catches mismatches before runtime.

---

## Next Steps

1. **Start:** [Build your first Dream server](guides/getting-started.md) - Get something running
2. **Explore:** [Examples](examples.md) - Read commented, working code
3. **Reference:** [Architecture](reference/architecture.md) - Deep technical dive

**The examples are your documentation.** They're commented, tested, and production-ready. Read them.
