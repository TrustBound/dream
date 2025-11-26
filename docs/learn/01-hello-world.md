# Lesson 1: Hello World

**Goal:** Understand Dream's three core pieces

Your first Dream app is just one file with three pieces: a router, a controller, and a server.

## The Complete App

Create `src/hello_dream.gleam`:

```gleam
import dream/http.{type Request, type Response, text_response, ok}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, route, router}
import dream/servers/mist/server.{
  bind, listen, new, router as set_router, services,
} as server

fn index(
  _request: Request,
  _context: dream/context.AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn main() {
  let app_router =
    router()
    |> route(method: Get, path: "/", controller: index, middleware: [])

  server.new()
  |> router(app_router)
  |> bind("localhost")
  |> listen(3000)
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

```gleam
fn index(
  _request: Request,
  _context: dream/context.AppContext,
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

```gleam
let app_router =
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
```

The router matches incoming requests to controllers:
- `method: Get` - Only match GET requests
- `path: "/"` - Only match the root path
- `controller: index` - Call our index function
- `middleware: []` - No middleware (yet)

### 3. The Server

```gleam
server.new()
|> router(app_router)
|> bind("localhost")
|> listen(3000)
```

This configures and starts the server:
- `router()` - Use our router
- `bind()` - Listen on localhost only
- `listen()` - Start on port 3000

**Note:** Dream defaults to `AppContext` and `EmptyServices`. For simple apps, you only need to provide a router. We will see custom context and custom services in later lessons.

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

