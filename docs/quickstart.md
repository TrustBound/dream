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

Create a project with `gleam new hello_dream`, go into its folder with `cd hello_dream`, and add Dream:

```bash
gleam add dream
```

## Write Your Server

Replace `src/hello_dream.gleam`:

### The server file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Run It

Run `gleam run` in the project folder, then visit http://localhost:3000 - you should see "Hello, World!"

## How It Works

Let’s walk through the file from top to bottom.

### Imports

#### The imports <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam#L5-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server
```

In words:

- `dream/context` gives you `EmptyContext`, the default context type.
- `dream/http` gives you the **Request** and **Response** types plus
  helpers like `text_response` and common status codes like `ok`.
- `dream/http/request.{Get}` brings in the HTTP method you will use in
  the router.
- `dream/router` gives you the `Router` and `EmptyServices` types and
  the `router()` and `route(...)` functions.
- `dream/servers/mist/server` is the entrypoint for running Dream on
  the Mist HTTP server. We call its builder functions with the module
  name, for example `server.new()` and `server.router(...)`.

### The controller

#### The index controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam#L11-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn index(
  _request: Request,
  _context: EmptyContext,
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

#### The app router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam#L19-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}
```

`create_app_router()` returns the router. `router()` creates an empty router.

`route(...)` adds one route:

- `method: Get` – only match HTTP GET requests.
- `path: "/"` – only match the root path.
- `controller: index` – call the `index` controller above.
- `middleware: []` – no middleware yet.

The `|>` operator is Gleam’s **pipe** operator. It takes the value on the
left and passes it as the **last argument** to the function on the
right. You can read it as “then”.

So:

#### An empty router, then a route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam#L20-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
```

means “start with an empty router, **then** add this route”.

### The server

#### Starting the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/quickstart_hello_server.gleam#L24-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  server.new()
  |> server.router(create_app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
```

Here we build and start the server:

- `server.new()` – create a Dream server with default context and
  services.
- `|> server.router(create_app_router())` – attach the router.
- `|> server.bind("localhost")` – listen only on the local machine.
- `|> server.listen(3000)` – start listening on port 3000 and block forever.

Because Dream uses a **builder pattern**, each call returns a new value
with more configuration applied. There is no global state.

> Note: When using Dream’s default `EmptyContext`, you don’t need to call
> `server.context()` explicitly – it is set up automatically.

> Note: If you add `server.context()` or `server.services()`, call them
> before `server.router()`. `server.listen()` comes after `server.router()`.
> The compiler enforces this order: the router's type includes the context
> and services types. See [Builder order](concepts.md#builder-order).

### A note on performance

Dream uses a radix trie for routing, giving O(path depth) lookup
performance. This means 1000 routes perform nearly as fast as 10 routes
(~1.3μs per lookup regardless of route count). The router is fast enough
that it won’t be your bottleneck for typical apps.

## The Same Server, Shorter

Gleam infers types, so a small server can leave out its type annotations. This version is the example in the Dream README. It does the same job as the server above.

### Hello, world <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_hello_server.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_request, _context, _services) {
  text_response(ok, "Hello, world!")
}

pub fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn main() {
  server.new()
  |> server.router(app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
```

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

