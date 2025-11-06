# Getting Started with Dream

**Prerequisites:** Basic Gleam knowledge, Erlang/OTP installed, Gleam installed.

If you're coming from frameworks that hide everything behind magic configuration files, buckle up. Dream shows you exactly what's happening.

## Installation

Add Dream to your `gleam.toml`:

```toml
[dependencies]
dream = ">= 0.0.1"
gleam_stdlib = ">= 0.44.0"
```

Run:

```bash
gleam deps download
```

That's it. No configuration files. No framework CLI tools. No "generators."

## Your First Dream App

Let's build a simple web server. We'll create three files—no more, no less.

### Step 1: Create the Main File

Create `src/your_app.gleam`:

```gleam
import dream/core/context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import your_app/router.{create_router}
import your_app/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

See that? Everything your app does is right there. No hidden startup code. No "convention over configuration" nonsense. You can read this and understand exactly what's happening.

Let's break it down:

- `dream.new()` - Creates a new Dream server instance
- `.context(AppContext(...))` - Sets up per-request context (you can customize this later)
- `.services(initialize_services())` - Injects your dependencies (database, etc.)
- `.router(create_router())` - Wires up your routes
- `.bind("localhost")` - Which host to bind to
- `.listen(3000)` - Which port to listen on

This is the **builder pattern**. Every step is explicit. No surprises.

### Step 2: Create Your Router

Create `src/your_app/router.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import your_app/controllers/hello_controller

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    controller: hello_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/hello/:name",
    controller: hello_controller.greet,
    middleware: [],
  )
}
```

Routes are functions that return a `Router`. Want to add a route? Call `route()`. Want to remove a route? Don't call `route()`. Revolutionary.

### Step 3: Create Your Controller

Create `src/your_app/controllers/hello_controller.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/statuses.{ok_status}
import dream/core/http/transaction.{
  type Request, type Response, get_param, text_response,
}
import dream/core/router.{type EmptyServices}

pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok_status(), "Hello, World!")
}

pub fn greet(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  let assert Ok(name) = get_param(request, "name")
  text_response(ok_status(), "Hello, " <> name <> "!")
}
```

Controllers are just functions with a specific signature:

```gleam
fn(Request, Context, Services) -> Response
```

No base classes. No inheritance. No decorators. Just a function that takes a request and returns a response. Like the web was meant to be.

### Step 4: Create Your Services

Create `src/your_app/services.gleam`:

```gleam
import dream/core/router.{type EmptyServices, EmptyServices}

pub fn initialize_services() -> EmptyServices {
  EmptyServices
}
```

For now, we have no services (no database, no external APIs). When you need them, you'll add them here. Explicitly.

### Step 5: Run It

```bash
gleam run
```

Your server is now running at `http://localhost:3000`.

Try it:

```bash
curl http://localhost:3000/
# Output: Hello, World!

curl http://localhost:3000/hello/Alice
# Output: Hello, Alice!
```

## Understanding the Builder Pattern

Dream uses the builder pattern everywhere. You've seen it in `main()`:

```gleam
dream.new()
  |> context(...)
  |> services(...)
  |> router(...)
  |> bind(...)
  |> listen(...)
```

You'll see it in routers:

```gleam
router
  |> route(method: Get, path: "/", ...)
  |> route(method: Post, path: "/users", ...)
```

And in HTTP clients:

```gleam
client.new
  |> client.method(http.Get)
  |> client.host("api.example.com")
  |> client.path("/users")
```

Why? Because it's **explicit and readable**. You can see the configuration flowing through. Each step transforms the previous value. No global state. No side effects.

## Understanding the Request Pipeline

When a request comes in, here's what happens:

1. **Mist receives the HTTP request** (the underlying BEAM web server)
2. **Dream parses it** into a `Request` type
3. **Router matches the path** against your route definitions
4. **Middleware executes** (if you have any) in the order you defined
5. **Controller function runs** with `(Request, Context, Services)`
6. **Controller returns a `Response`**
7. **Dream sends it back** through Mist to the client

No magic. No hidden processing. Just a straightforward pipeline.

## What About Context and Services?

You might be wondering about those `_context` and `_services` parameters we're ignoring.

**Context** is per-request data. Think: request ID, user session, authentication info. It's mutable—middleware can modify it as the request flows through the pipeline.

**Services** is application-level dependencies. Think: database connections, HTTP clients, caches. It's immutable—set once at startup, used everywhere.

We'll cover these in detail in the tutorials. For now, just know:

- Controllers receive **three parameters**: `Request`, `Context`, `Services`
- Middleware can **modify context** as requests flow through
- Services are **injected once** at application startup

## Next Steps

You've built your first Dream app. Not bad for 30 lines of code.

**Ready for more?**

- [Tutorial: Basic Routing](tutorials/basic-routing.md) - Path parameters, multiple methods
- [Tutorial: Database CRUD](tutorials/database-crud.md) - PostgreSQL, models, and controllers
- [Tutorial: Authentication](tutorials/authentication.md) - Custom context and middleware
- [Architecture Reference](reference/architecture.md) - Deep dive into how it all works

**Want to see working examples?**

Check out `src/examples/` in the Dream repository:
- `simple/` - What you just built (plus HTTP client usage)
- `database/` - Full CRUD with PostgreSQL
- `custom_context/` - Authentication with custom context
- `streaming/` - HTTP client with streaming responses

## Common Questions

### Do I need a database?

Nope. Dream doesn't force anything on you. Add `pog` and `squirrel` when you need PostgreSQL. Or use something else. Up to you.

### Can I use a different HTTP server?

Theoretically yes—Dream's design is composable. But Mist is solid and runs on the BEAM, so you probably don't need to.

### Where's the ORM?

There isn't one. We use [Squirrel](https://github.com/giacomocavalieri/squirrel) for type-safe SQL queries. Because ORMs that "help" you by hiding SQL usually just make debugging harder.

### What about sessions, authentication, WebSockets, [feature X]?

Dream is a library, not a framework. We provide the building blocks. You compose them. Check the examples and guides for patterns you can use.

---

**[← Back to README](../README.md)** | **[Next: Basic Routing Tutorial →](tutorials/basic-routing.md)**

