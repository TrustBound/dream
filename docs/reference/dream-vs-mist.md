# Dream vs Raw Mist

Side-by-side comparison showing exactly what Dream adds over raw Mist.

## Simple Route

### With Raw Mist

#### Raw Mist: hello world <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_simple_mist.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import mist.{type Connection, type ResponseData}

pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  case mist.read_body(request, max_body_limit: 1_000_000) {
    Ok(request_with_body) -> route_request(request_with_body)
    Error(_read_error) ->
      response.new(400)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn route_request(request: Request(BitArray)) -> Response(ResponseData) {
  case request.method, request.path {
    Get, "/" ->
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello, World!")))
      |> response.set_header("content-type", "text/plain")
    _, _ ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
  }
}

pub fn main() {
  let started =
    mist.new(handle_request)
    |> mist.port(3000)
    |> mist.start()

  case started {
    Ok(_server) -> process.sleep_forever()
    Error(_start_error) -> io.println("The server did not start")
  }
}
```

**Issues:**
- Manual body reading
- Manual routing with pattern matching
- Manual response construction
- No type safety across routes

### With Dream

#### Dream: hello world <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_simple_dream.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn show_home(_request: Request, _context, _services) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn create_router() {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
}

pub fn main() {
  server.new()
  |> server.router(create_router())
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

#### Raw Mist: parse the path by hand <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_params_mist.gleam#L14-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  case request.method, parse_user_path(request.path) {
    Get, Ok(id) -> show_user(id)
    _, _ -> not_found()
  }
}

fn parse_user_path(path: String) -> Result(Int, Nil) {
  case string.split(path, "/") {
    ["", "users", id_text] -> int.parse(id_text)
    _ -> Error(Nil)
  }
}

fn show_user(id: Int) -> Response(ResponseData) {
  // How does this function reach the database? A global? The process
  // dictionary? One more argument on every function in between?
  response.new(200)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string("User " <> int.to_string(id))),
  )
}

fn not_found() -> Response(ResponseData) {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
}
```

**Issues:**
- Write path parser for every pattern
- No database connection available
- No type safety

### With Dream

#### Dream: read the id parameter <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_params_dream.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, json_response, ok, require_int, text_response,
}
import dream/http/error.{type Error, NotFound}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server
import gleam/json
import gleam/list
import gleam/result

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(users: List(User))
}

pub fn show_user(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user_result = {
    use id <- result.try(require_int(request, "id"))
    find_user(services.users, id)
  }

  case user_result {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(http_error) ->
      text_response(error.to_status_code(http_error), error.message(http_error))
  }
}

fn find_user(users: List(User), id: Int) -> Result(User, Error) {
  list.find(users, fn(user) { user.id == id })
  |> result.replace_error(NotFound("User not found"))
}

fn user_to_json(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string()
}

pub fn initialize_services() -> Services {
  Services(users: [User(id: 1, name: "Ada")])
}

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
}

pub fn main() {
  server.new()
  |> server.services(initialize_services())
  |> server.router(create_router())
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

#### Raw Mist: check the token in the handler <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_middleware_mist.gleam#L17-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  // Every request needs a token, so no route can be public
  case authenticate(request) {
    Ok(user) -> handle_route(request, user)
    Error(Nil) -> send_text(401, "Unauthorized")
  }
}

fn authenticate(request: Request(Connection)) -> Result(User, Nil) {
  use token <- result.try(request.get_header(request, "authorization"))
  verify_token(token)
}

fn verify_token(token: String) -> Result(User, Nil) {
  case token {
    "Bearer secret-token" -> Ok(User(name: "Ada"))
    _ -> Error(Nil)
  }
}

fn handle_route(
  request: Request(Connection),
  user: User,
) -> Response(ResponseData) {
  case request.method, request.path {
    Get, "/" -> show_home(user)
    Post, "/posts" -> create_post(request, user)
    _, _ -> send_text(404, "Not Found")
  }
}

fn show_home(user: User) -> Response(ResponseData) {
  send_text(200, "Welcome, " <> user.name)
}

fn create_post(
  _request: Request(Connection),
  user: User,
) -> Response(ResponseData) {
  send_text(201, "Post created by " <> user.name)
}
```

**Issues:**
- Duplicate auth logic for each route
- No way to make some routes public, some protected
- Manual user threading

### With Dream

#### Dream: auth middleware on one route <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_middleware_dream.gleam#L29-L90"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn auth_middleware(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case authenticate(request, services) {
    Ok(user) -> {
      let enriched_context = Context(..context, user: Some(user))
      next(request, enriched_context, services)
    }
    Error(Nil) -> text_response(unauthorized, "Unauthorized")
  }
}

fn authenticate(request: Request, services: Services) -> Result(User, Nil) {
  use token <- result.try(
    get_header(request.headers, "Authorization") |> option.to_result(Nil),
  )
  list.key_find(services.users_by_token, token)
}

pub fn show_home(
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  text_response(ok, "Welcome")
}

pub fn create_post(
  _request: Request,
  context: Context,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> text_response(created, "Post created by " <> user.name)
    None -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn create_router() -> Router(Context, Services) {
  router()
  // Public
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  // Protected
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}

pub fn initialize_services() -> Services {
  Services(users_by_token: [#("Bearer secret-token", User(name: "Ada"))])
}

pub fn main() {
  server.new()
  |> server.context(Context(request_id: "", user: None))
  |> server.services(initialize_services())
  |> server.router(create_router())
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

#### Raw Mist: handlers with different signatures <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_middleware_mist.gleam#L48-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn show_home(user: User) -> Response(ResponseData) {
  send_text(200, "Welcome, " <> user.name)
}

fn create_post(
  _request: Request(Connection),
  user: User,
) -> Response(ResponseData) {
  send_text(201, "Post created by " <> user.name)
}
```

Each handler takes different arguments. Nothing ties them together, so the compiler cannot check that every route gets what it needs.

### With Dream

#### Dream: one controller type for every route <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/dream_vs_mist_middleware_dream.gleam#L51-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_home(
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  text_response(ok, "Welcome")
}

pub fn create_post(
  _request: Request,
  context: Context,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> text_response(created, "Post created by " <> user.name)
    None -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn create_router() -> Router(Context, Services) {
  router()
  // Public
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  // Protected
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}
```

The router has the type `Router(Context, Services)`, and every controller has the type `fn(Request, Context, Services) -> Response`. If you change `Context` or `Services`, the compiler finds every place that needs an update.

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

