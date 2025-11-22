<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200" alt="Ricky Moony and Lucy, a moon shaped mascot for Dream with the star shaped mascot for Gleam, each with cute cartoon eyes and a smile">

  <b>Clean, composable web development for Gleam. No magic.</b>
</div>

<div align="center">
  <a href="https://github.com/TrustBound/dream/releases">
    <img src="https://img.shields.io/github/v/release/TrustBound/dream?label=Release" alt="Latest Release">
  </a>
  <a href="https://hexdocs.pm/dream">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

## What is Dream?

Dream is a web toolkit for building servers. It's not a framework—you control everything. No hidden configuration, no magic middleware appearing from nowhere. Your `main()` function shows exactly what's happening.

**Built for Gleam** (a type-safe functional language) and **runs on the BEAM** (the same runtime that powers WhatsApp, Discord, and millions of concurrent connections).

## A Complete Example

Here's a working web server. Every line explained:

```gleam
import dream/context
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, route, router}
import dream/servers/mist/server.{
  bind, context, listen, router as set_router, services,
}

// This is a controller action: a function that handles HTTP requests
// It takes: the request, context (per-request data), and services (shared dependencies)
// It returns: an HTTP response
fn index(
  _request: Request,           // The HTTP request (we don't use it here)
  _context: context.AppContext, // Per-request data (request ID, user, etc.)
  _services: EmptyServices,     // Shared dependencies (database, cache, etc.)
) -> Response {
  // Return a plain text response with status 200
  text_response(status.ok, "Hello, World!")
}

// This is your main function - it sets up and starts the server
pub fn main() {
  // Create a router and define one route
  // When someone visits "/", call the index function
  let app_router =
    router
    |> route(method: Get, path: "/", controller: index, middleware: [])

  // Build the server configuration
  server.new()
    |> context(context.AppContext(request_id: ""))  // Default context (just a request ID)
    |> services(router.EmptyServices)                // No shared services yet
    |> set_router(app_router)                        // Use the router we created
    |> bind("localhost")                             // Listen on localhost
    |> listen(3000)                                  // Port 3000
}
```

**Run this:** `gleam run` → Visit `http://localhost:3000` → See "Hello, World!"

## Why This Approach?

**Everything is explicit.** You can see exactly where your database connection comes from. No globals, no hidden state, no framework magic.

**Controller actions are just functions.** No base classes, no decorators, no inheritance. Extract parameters, do work, return a response.

**Type-safe routing.** The compiler verifies your routes match your controllers. Change a function signature? The compiler shows you every route that needs updating.

**Composable, not opinionated.** Use Dream's patterns, or build your own. It's just functions and data.

## Learn More

- 📚 [Complete Documentation](https://github.com/TrustBound/dream/blob/main/docs/index.md) - Guides, tutorials, and concepts
- 📖 [API Reference](https://hexdocs.pm/dream) - Complete API documentation on HexDocs
- 🚀 [5-Minute Quickstart](https://github.com/TrustBound/dream/blob/main/docs/quickstart.md) - Get a server running
- 💡 [Examples](https://github.com/TrustBound/dream/tree/main/examples) - Working code you can run

## Why Gleam? Why the BEAM?

**Gleam** is a type-safe functional language. You get compile-time error checking, no nulls, and a modern syntax. Learn it in a weekend.

**The BEAM** is the runtime that powers Erlang and Elixir. It was built for reliability and concurrency:
- **Millions of concurrent connections** per server (WhatsApp: 2.8M per server)
- **Fault tolerance** - processes crash in isolation, the rest keep running
- **Hot code reloading** - update code without dropping connections

**Real-world results:**
- Discord: 12M+ concurrent users, 26M WebSocket events/sec with ~5 engineers
- Remote: Grew from zero to unicorn (~$3B) in ~2 years with Elixir
- BBC: Elixir serving almost all BBC web and app traffic

Gleam gives you the BEAM's superpowers with type safety. You write functions. The BEAM handles concurrency, fault tolerance, and scaling.

[Read more about why Gleam and the BEAM →](https://github.com/TrustBound/dream/blob/main/docs/index.md)

## Philosophy

Dream is **explicitly not a framework**. We provide:

✅ Clean interfaces and types  
✅ Common patterns (controllers, models, middleware)  
✅ Useful utilities (validation, response builders)  
✅ Working examples

You provide:

🎯 Your application structure  
🎯 Your router configuration  
🎯 Your controllers and models  
🎯 Your business logic

**No magic. No hidden behavior. Everything explicit.**

## Contributing

See the [Contributing Guide](https://github.com/TrustBound/dream/blob/main/docs/index.md#contributing) for guidelines.

## License

[MIT License](https://github.com/TrustBound/dream/blob/main/LICENSE.md)

---

*Built with Gleam. Runs on the BEAM. Works like you'd expect.*
