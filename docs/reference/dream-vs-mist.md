# Dream vs Raw Mist

Side-by-side comparison showing exactly what Dream adds over raw Mist.

## Simple Route

### With Raw Mist

```gleam
import mist
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bytes_tree

pub fn main() {
  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    case mist.read_body(req, max_body_limit: 1_000_000) {
      Ok(_req_with_body) -> {
        case req.method, req.path {
          http.Get, "/" -> {
            response.new(200)
            |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello, World!")))
            |> response.set_header("Content-Type", "text/plain")
          }
          _, _ -> {
            response.new(404)
            |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
          }
        }
      }
      Error(_) -> response.new(400) |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }
  
  mist.new(handler)
  |> mist.port(3000)
  |> mist.start_http()
  |> result.unwrap(Nil)
}
```

**Issues:**
- Manual body reading
- Manual routing with pattern matching
- Manual response construction
- No type safety across routes

### With Dream

```gleam
import dream/http.{type Request, type Response, text_response, ok}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_req: Request, _ctx, _svc) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn main() {
  let app_router = router |> route(Get, "/", index, [])
  
  server.new()
  |> server.router(app_router)
  |> server.listen(3000)
}
```

**Dream provides:**
- Automatic body reading
- Pattern-based routing
- Response builders
- Type-safe controller signatures

---

## Path Parameters

### With Raw Mist

```gleam
fn handler(req: Request(Connection)) -> Response(ResponseData) {
  case req.method, req.path {
    http.Get, path -> {
      // Manual path parsing
      case parse_user_path(path) {
        Ok(id) -> show_user(id)
        Error(_) -> not_found()
      }
    }
    _, _ -> not_found()
  }
}

fn parse_user_path(path: String) -> Result(Int, Nil) {
  case string.split(path, "/") {
    ["", "users", id_str] -> {
      case int.parse(id_str) {
        Ok(id) -> Ok(id)
        Error(_) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn show_user(id: Int) -> Response(ResponseData) {
  // How do we get database connection here?
  // Global? Thread through? Process dictionary?
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("User " <> int.to_string(id))))
}
```

**Issues:**
- Write path parser for every pattern
- No database connection available
- No type safety

### With Dream

```gleam
import dream/http.{type Request, type Response, require_int, json_response, text_response, ok, not_found}
import dream/http/request.{Get}
import dream/router.{Router, route, router}
import dream/context.{AppContext}
import models/user.{get}
import services.{Services}
import views/user_view.{to_json}

fn show_user(request: Request, context: AppContext, services: Services) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    get(db, id)
  }
  
  case result {
    Ok(user) -> json_response(ok, to_json(user))
    Error(err) -> response_helpers.handle_error(err)
  }
}

pub fn main() {
  let app_router = router |> route(Get, "/users/:id", show_user, [])
  
  server.new()
  |> server.services(initialize_services())
  |> server.router(app_router)
  |> server.listen(3000)
}
```

**Dream provides:**
- Automatic parameter extraction (`require_int`, `require_string`)
- Type-safe dependency injection (Services)
- Clean controller signature

---

## Middleware

### With Raw Mist

```gleam
fn handler(req: Request(Connection)) -> Response(ResponseData) {
  // Manually check auth on every route
  case get_header(req.headers, "Authorization") {
    None -> unauthorized()
    Some(token) -> {
      case verify_token(token) {
        Error(_) -> unauthorized()
        Ok(user) -> {
          // How do we pass user to the route handler?
          // Process dictionary? Global? Thread through?
          handle_route(req, user)
        }
      }
    }
  }
}

fn handle_route(req: Request(Connection), user: User) -> Response(ResponseData) {
  case req.method, req.path {
    http.Get, "/" -> home_handler(user)
    http.Post, "/posts" -> create_post_handler(req, user)
    _, _ -> not_found()
  }
}
```

**Issues:**
- Duplicate auth logic for each route
- No way to make some routes public, some protected
- Manual user threading

### With Dream

```gleam
fn auth_middleware(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> unauthorized()
    Some(token) -> {
      case verify_token(token) {
        Error(_) -> unauthorized()
        Ok(user) -> {
          let enriched_context = Context(..context, user: Some(user))
          next(request, enriched_context, services)
        }
      }
    }
  }
}

pub fn main() {
  let app_router =
    router
    |> route(Get, "/", home, [])                      // Public
    |> route(Post, "/posts", create_post, [auth_middleware])  // Protected
  
  server.new()
  |> server.router(app_router)
  |> server.listen(3000)
}
```

**Dream provides:**
- Reusable middleware
- Per-route middleware application
- Context enrichment
- Type-safe middleware chaining

---

## Type Safety

### With Raw Mist

```gleam
// No type relationship between routes
fn route1(req) -> Response { ... }
fn route2(req, db) -> Response { ... }  // Different signature!
fn route3(req) -> Response { ... }

// Compiler can't verify all routes work together
```

### With Dream

```gleam
Router(Context, Services)  // Router knows types
Route(Context, Services)   // Each route matches
fn(Request, Context, Services) -> Response  // Every controller has this signature

// If you change Context or Services, compiler catches every place that needs updating
```

**Dream provides:**
- Type-checked application
- Compiler verifies all controllers match router
- Changing dependencies is safe (compiler finds all usages)

---

## What Dream Actually Adds

| Feature | Raw Mist | With Dream |
|---------|----------|------------|
| **Routing** | Manual string parsing | Pattern-based with `:params` |
| **Path params** | Write parser per route | `require_int(request, "id")` |
| **Dependencies** | Globals or process dictionary | Type-safe Services parameter |
| **Per-request data** | Thread manually or use process dictionary | Type-safe Context parameter |
| **Middleware** | Reimplement per project | Built-in, composable |
| **Response building** | Manual status + headers | `json_response(200, body)` |
| **JSON validation** | Manual decode + error handling | `validate_json(body, decoder)` |
| **Type safety** | Routes are isolated | Compiler verifies whole app |

---

## When to Use What

**Use Raw Mist when:**
- You need absolute minimal dependencies
- Building a tiny service (1-2 routes)
- You want complete control over everything

**Use Dream when:**
- You have 3+ routes
- You need database or other services
- You want middleware (auth, logging)
- You want type safety across your app
- You're building something that will grow

---

## See Also

- [Architecture](architecture.md) - How Dream is structured
- [Design Principles](design-principles.md) - Why Dream is built this way

