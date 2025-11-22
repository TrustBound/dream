# 5-Minute Quickstart

Get a Dream web server running in 5 minutes.

## Prerequisites

- [Gleam installed](https://gleam.run/getting-started/installing/)
- 5 minutes

## Create Your Project

```bash
gleam new hello_dream
cd hello_dream
gleam add dream
```

## Write Your Server

Replace `src/hello_dream.gleam`:

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
    router
    |> route(method: Get, path: "/", controller: index, middleware: [])

  server.new()
  |> services(EmptyServices)
  |> set_router(app_router)
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

This code does three things:

1. **Router** - `route(Get, "/", index, [])` says "GET requests to / call the index function"
2. **Controller** - `index()` returns a text response
3. **Server** - `server.new()` configures and starts the server on port 3000

**Note:** When using Dream's default `AppContext`, you don't need to call `context()` - it's automatic.

## What's Next?

### Learn Core Concepts

- [Learning Path](learn/) - 2-hour structured course
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
- [All Examples](../examples/) - 7 working applications with 63 tests

**Want to understand this code?** Start with [Hello World](learn/01-hello-world.md) in the learning path.

