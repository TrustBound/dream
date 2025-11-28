# Quickstart

Get a Dream web server running in a few minutes.

This quickstart is for people who are **new to Dream** and maybe also
new to Gleam. We will:

- Create a minimal project.
- Write one small server file.
- Explain what each piece does in plain language.

You do **not** need to know Erlang/OTP or BEAM internals.

## Prerequisites

- [Gleam installed](https://gleam.run/getting-started/installing/)
- A few minutes of time

## Create Your Project

```bash
gleam new hello_dream
cd hello_dream
gleam add dream
```

## Write Your Server

Replace `src/hello_dream.gleam`:

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, text_response, ok}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, route, router as create_router}
import dream/servers/mist/server.{bind, listen, router}

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn main() {
  let app_router =
    create_router()
    |> route(method: Get, path: "/", controller: index, middleware: [])

  server.new()
  |> router(app_router)
  |> bind("localhost")
  |> listen(3000)
}
```

## Run It

```bash
gleam run
```

Visit http://localhost:3000 - you should see "Hello, World!"

## How It Works

Let’s walk through the file from top to bottom.

### Imports

```gleam
import dream/http.{type Request, type Response, text_response, ok}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, route, router}
import dream/servers/mist/server.{
  bind, listen, new, router as set_router, services,
} as server
```

In words:

- `dream/http` gives you the **Request** and **Response** types plus
  helpers like `text_response` and common status codes like `ok`.
- `dream/http/request.{Get}` brings in the HTTP method you will use in
  the router.
- `dream/router` gives you the router type and the `router()` and
  `route(...)` functions.
- `dream/servers/mist/server` is the entrypoint for running Dream on
  the Mist HTTP server. We import it as `server` and pull in the
  builder-style functions we need.

### The controller

```gleam
fn index(
  _request: Request,
  _context: dream/context.AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}
```

This function is your **controller**. It:

- Receives a `Request`, a `Context`, and `Services`.
- Ignores them for now (the `_` prefix means “unused parameter”).
- Returns a `Response` created with `text_response(status, body)`.

You can imagine it as:

> "Whenever someone visits this route, send back 200 OK with the text
>  `Hello, World!`."

### The router

```gleam
pub fn main() {
  let app_router =
    router()
    |> route(method: Get, path: "/", controller: index, middleware: [])
```

`router()` creates an empty router.

`route(...)` adds one route:

- `method: Get` – only match HTTP GET requests.
- `path: "/"` – only match the root path.
- `controller: index` – call the `index` controller above.
- `middleware: []` – no middleware yet.

The `|>` operator is Gleam’s **pipe** operator. It takes the value on the
left and passes it as the **last argument** to the function on the
right. You can read it as “then”.

So:

```gleam
router()
|> route(...)
```

means “start with an empty router, **then** add this route”.

### The server

```gleam
  server.new()
  |> router(app_router)
  |> bind("localhost")
  |> listen(3000)
}
```

Here we build and start the server:

- `server.new()` – create a Dream server with default context and
  services.
- `|> router(app_router)` – attach the router you just built.
- `|> bind("localhost")` – listen only on the local machine.
- `|> listen(3000)` – start listening on port 3000 and block forever.

Because Dream uses a **builder pattern**, each call returns a new value
with more configuration applied. There is no global state.

> Note: When using Dream’s default `AppContext`, you don’t need to call
> `context()` explicitly – it is set up automatically.

### A note on performance

Dream uses a radix trie for routing, giving O(path depth) lookup
performance. This means 1000 routes perform nearly as fast as 10 routes
(~1.3μs per lookup regardless of route count). The router is fast enough
that it won’t be your bottleneck for typical apps.

## What's Next?

### Learn Core Concepts

- [Learning Path](learn/) - Structured set of short lessons
- [How It Works](concepts/how-it-works.md) - Request flow explained

### Build Something Specific

- [Authentication](guides/authentication.md) - Add JWT or session auth
- [Database](guides/controllers-and-models.md) - Connect to PostgreSQL
- [Streaming](guides/streaming.md) - Handle large files and real-time data
- [Multiple Formats](guides/multiple-formats.md) - Serve JSON, HTML, CSV

### Explore Examples

- [`examples/database`](../examples/database/) - Full CRUD API with PostgreSQL
- [`examples/streaming_capabilities`](../examples/streaming_capabilities/) - Advanced streaming
- [`examples/multi_format`](../examples/multi_format/) - JSON/HTML/CSV/HTMX
- [All Examples](../examples/) - Multiple working applications with extensive integration tests

**Want to understand this code?** Start with [Hello World](learn/01-hello-world.md) in the learning path.

