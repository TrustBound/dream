# Lesson 1: Hello World

**Goal:** Understand Dream's three core pieces

Your first Dream app is just one file with three pieces: a router, a controller, and a server.

## The Complete App

Create `src/hello_dream.gleam`:

### The Hello World app <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/learn_hello_world_app.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn create_app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn main() {
  server.new()
  |> server.router(create_app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
```

Run it:

```bash
gleam run
```

Visit http://localhost:3000 - you should see "Hello, World!"

## How It Works

We’ll go through the file in three passes: controller, router, server.
Along the way we’ll also explain some Gleam syntax.

### 1. The Controller

#### The index controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/learn_hello_world_app.gleam#L11-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}
```

This is a controller – a function that:

- Takes a `Request`, `Context`, and `Services`.
- Returns a `Response`.

In this very first example we do not need any information from the
request or services, so the parameters are prefixed with `_` to tell
Gleam “we know this argument is here, but we are not using it yet”.
We will start using them in later lessons.

### 2. The Router

#### The app router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/learn_hello_world_app.gleam#L19-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}
```

`create_app_router` builds the router. The router matches incoming requests to controllers:
- `method: Get` - Only match GET requests
- `path: "/"` - Only match the root path
- `controller: index` - Call our index function
- `middleware: []` - No middleware (yet)

### 3. The Server

#### Starting the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/learn_hello_world_app.gleam#L24-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  server.new()
  |> server.router(create_app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
```

This configures and starts the server:
- `server.new()` - Create a server with the default context and services
- `server.router(create_app_router())` - Use our router
- `server.bind("localhost")` - Listen on localhost only
- `server.listen(3000)` - Start on port 3000

**Note:** Dream defaults to `EmptyContext` and `EmptyServices`. For simple apps, you only need to provide a router. We will see custom context and custom services in later lessons.

## What You Learned

✅ Controllers are functions that take Request/Context/Services and return Response  
✅ Routers match requests to controllers  
✅ Dream uses builder pattern for configuration  
✅ This is all you need for simple apps

## For Simple Apps, You're Done

If you just need a few routes and some simple logic, this pattern is enough. Everything in one file, no complexity.

## Next Lesson

When you need multiple routes, path parameters, or a database, continue to [Lesson 2: Building an API](02-building-api.md).

---

**Working example:** See [examples/simplest/](../../examples/simplest/) for the complete runnable code.

