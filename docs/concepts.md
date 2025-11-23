# Dream Concepts

Everything you need to understand Dream. Read this, then explore the examples.

---

## Controllers

A controller is a module that contains action functions—public functions that handle HTTP requests. Each action takes a request, some context about that request, and your app's shared services (like a database connection), then returns a response.

```gleam
fn(Request, Context, Services) -> Response
```

That's it. No magic, no hidden state. The Request has the HTTP method, path, headers, and body. Context holds per-request data like the authenticated user. Services are your shared dependencies—database, cache, HTTP clients—things that don't change between requests.

Here's what a controller module looks like with two actions:

```gleam
// controllers/hello_controller.gleam
import dream/http.{type Request, type Response, text_response, ok}
import dream/context.{type AppContext}
import dream/router.{type EmptyServices}

pub fn hello_world(_request: Request, _context: EmptyContext, _services: EmptyServices) -> Response {
  text_response(status.ok, "Hello, World!")
}

pub fn hello_name(request: Request, _context: EmptyContext, _services: EmptyServices) -> Response {
  let result = {
    use name <- result.try(require_string(request, "name"))
    Ok(name)
  }
  
  case result {
    Ok(name) -> text_response(status.ok, "Hello, " <> name <> "!")
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

Actions orchestrate the request → response flow. They parse parameters, call models to fetch data, call operations for complex business logic, call views to format output, map errors to HTTP status codes, and build responses.

Use controllers for simple CRUD operations, single-model operations, or any direct request → model → view flow. Most of your endpoints will be controller actions.

**See:** [examples/database/src/controllers/](../examples/database/src/controllers/)

---

## Router

The router matches incoming requests to your controller actions based on HTTP method and path pattern. You define routes like this:

```gleam
pub fn create_router() -> Router(AppContext, Services) {
  router()
  |> route(method: Get, path: "/users", controller: users_controller.index, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: users_controller.show, middleware: [])
  |> route(method: Post, path: "/users", controller: users_controller.create, middleware: [])
}
```

Path parameters like `:id` get extracted automatically. So `/users/:id` matches `/users/123` and makes `id` available via `require_int(request, "id")` or `require_string(request, "id")`. These functions safely extract and validate parameters, returning `Result` types for error handling. You can have multiple parameters too—`/posts/:post_id/comments/:id` extracts both.

The router is generic over your Context and Services types. This means the compiler verifies every controller action has the right signature. Change your Context or Services type? The compiler will tell you exactly which actions need updating.

**Important Note on Parameter Type Safety:** Dream's router validates path parameters at runtime, not compile-time. If you change `/users/:id` to `/users/:user_id` in your route, but forget to update your controller code from `get_param(request, "id")` to `get_param(request, "user_id")`, the compiler won't catch this—you'll get a runtime error. This design prioritizes API ergonomics and flexibility over compile-time guarantees. We're exploring more type-safe alternatives in [Discussion #15](https://github.com/TrustBound/dream/discussions/15).

**Router Performance:** Dream uses a radix trie for O(path depth) route matching. Benchmarks show consistent ~1.3-1.5μs lookup times whether you have 100 or 1000 routes. The router is fast enough that it won't be your bottleneck.

**See:** [examples/simple/src/router.gleam](../examples/simple/src/router.gleam)

---

## Services

Your controller actions need things like database connections, HTTP clients, and caches. You could pass these through every function call, but that gets messy fast. You could use global variables, but Gleam doesn't have safe globals. You could use Erlang's process dictionary, but that's not type-safe.

Services solves this with type-safe dependency injection. You define what your app needs:

```gleam
pub type Services {
  Services(
    db: pog.Connection,
    cache: ets.Table,
  )
}
```

Initialize it once at startup:

```gleam
pub fn initialize_services() -> Services {
  let assert Ok(db) = init_database()
  let assert Ok(cache) = init_cache()
  Services(db: db, cache: cache)
}

pub fn main() {
  server.new()
  |> services(initialize_services())  // Called once
  |> router(create_router())
  |> listen(3000)
}
```

Now every controller action gets the same Services instance. Need to add a new service? Add one field to Services, and the compiler shows you everywhere that might need it.

Yes, Services is a "god object" that holds multiple dependencies. We're okay with that tradeoff because it makes adding cross-cutting concerns easy, keeps controller action signatures consistent, and the alternative—threading dependencies through every function—is worse.

**See:** [examples/database/src/services.gleam](../examples/database/src/services.gleam)

---

## Context

Context holds per-request data that changes for each request. Request A's authenticated user is different from Request B's authenticated user. That's what Context is for.

Dream provides `EmptyContext` for simple apps that don't need per-request data:

```gleam
pub type EmptyContext {
  EmptyContext
}
```

This is the default when you call `server.new()`. For apps that need request tracking, Dream also provides `AppContext`:

```gleam
pub type AppContext {
  AppContext(request_id: String)
}
```

But you'll probably want to add authentication with your own custom type:

```gleam
pub type AuthContext {
  AuthContext(
    request_id: String,
    user: Option(User),
  )
}
```

Middleware enriches the context before it reaches controllers. Here's how an auth middleware might work:

```gleam
pub fn auth_middleware(request, context, services, next) {
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
      next(request, enriched, services)  // Controller receives enriched context
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

```gleam
fn(Request, Context, Services, fn(Request, Context, Services) -> Response) -> Response
```

The fourth parameter is a function that represents the next middleware or controller action in the chain.

You get the request, context, services, and a `next` function. You can modify the request before calling `next`, enrich the context, call `next` (which passes control to the next middleware or controller action), modify the response after `next` returns, or short-circuit and return early.

Here's a logging middleware:

```gleam
pub fn logging_middleware(request, context, services, next) {
  let start_time = timestamp.now()
  
  // Call next (could be another middleware or the controller action)
  let response = next(request, context, services)
  
  let duration = timestamp.difference(timestamp.now(), start_time)
  log_request(request, response, duration)
  
  response  // Return (possibly modified) response
}
```

Apply middleware to routes:

```gleam
router
|> route(method: Get, path: "/", controller: home, middleware: [])  // Public
|> route(method: Post, path: "/admin", controller: admin, middleware: [
  auth_middleware,       // Run first
  admin_check_middleware, // Run second
  logging_middleware,    // Run third
])
```

Execution flows like an onion:

```
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

Sometimes a controller action needs to coordinate multiple services with complex business rules. That doesn't belong in an action.

Say you need to publish a post:
1. Get post from database
2. Verify user is the author
3. Update post status
4. Index in search engine
5. Broadcast event to subscribers

That's coordinating Postgres, OpenSearch, and SSE with authorization logic. Extract it to an operation:

```gleam
import dream/http.{require_int, type Request, type Response}
import dream/http.{json_response, ok}
import gleam/option
import gleam/result
import operations/publish_post
import utilities/response_helpers
import views/post_view

// Controller action stays thin - just HTTP concerns
pub fn publish(request: Request, context: Context, services: Services) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    use user <- result.try(
      case context.user {
        option.Some(u) -> Ok(u)
        option.None -> Error(error.Unauthorized("Authentication required"))
      }
    )
    publish_post.execute(id, user.id, services)
  }
  
  case result {
    Ok(post) -> json_response(ok, post_view.to_json(post))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

```gleam
import dream/http/error.{type Error, Forbidden, NotFound, InternalServerError}
import gleam/result

// Operation handles business logic - no HTTP
pub fn execute(post_id: Int, user_id: Int, services: Services) -> Result(Post, Error) {
  use post <- result.try(post_model.get(services.db, post_id))
  use _ <- result.try(check_authorization(user_id, post))
  use published <- result.try(post_model.publish(services.db, post_id))
  
  // Side effects
  let _ = search.index_post(services.search, published)
  let _ = events.broadcast(services.events, PostPublished(published))
  
  Ok(published)
}

fn check_authorization(user_id: Int, post: Post) -> Result(Nil, Error) {
  case user_id == post.author_id {
    True -> Ok(Nil)
    False -> Error(Forbidden("Not authorized to publish this post"))
  }
}
```

The big win? Operations are testable without HTTP. No mocking requests, no building Request objects—just test the business logic:

```gleam
pub fn publish_post_with_wrong_user_returns_forbidden_test() {
  let services = test_services()
  let post = create_test_post(services)
  
  let result = publish_post.execute(post.id, wrong_user_id, services)
  
  assert Error(error.Forbidden(_)) = result
}
```

Use operations when you're coordinating 2+ models, have complex business rules spanning entities, or need side effects like events, emails, or search indexing. Don't use them for simple CRUD—most controller actions don't need operations. Only extract when complexity demands it.

**See:** [examples/cms/src/operations/](../examples/cms/src/operations/)

---

## Models

Models handle data access. They take a database connection (explicit dependency, no globals), run queries, and convert database rows into your domain types. Controller actions call models, not SQL directly.

```gleam
// models/user/user.gleam
import dream/http/error.{type Error, NotFound, InternalServerError}

pub fn get(db: pog.Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

pub fn create(db: pog.Connection, data: UserData) -> Result(User, Error) {
  case sql.create_user(db, data.email, data.name) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
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

Models take connections as parameters, return domain types (not DB types), and handle the DB ↔ Domain conversion internally. Your controller actions stay clean—they just call `user.get(db, id)` and get a `User`, not a database row.

**See:** [examples/database/src/models/](../examples/database/src/models/)

---

## Views

Views format domain types into strings. JSON, HTML, CSV—whatever format you need. They're pure functions: take a domain type, return a string. No Result types, no HTTP knowledge.

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

Keep validation and response building separate. Validation takes a string and a decoder, returns `Result(T, ValidationError)`. Response building takes a status and body, returns a `Response`. Controllers connect them explicitly:

```gleam
case validate_json(request.body, decoder) {
  Ok(data) -> create_with_data(services, data)
  Error(err) -> json_response(status.bad_request, error_json(err))
}
```

**Models ≠ Views**

Models handle persistence and return domain types. Views format domain types and return strings. Controller actions orchestrate models and views. This separation makes each layer testable in isolation and keeps concerns clear.

---

## Putting It Together

When a request arrives:

```
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

1. **Start:** [5-Minute Quickstart](quickstart.md) - Get something running
2. **Explore:** [Examples](examples.md) - Read commented, working code
3. **Reference:** [Architecture](reference/architecture.md) - Deep technical dive

**The examples are your documentation.** They're commented, tested, and production-ready. Read them.
