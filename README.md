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

Here's a working web server with middleware:

```gleam
// Import Dream's empty context type (no per-request data needed)
import dream/context.{type EmptyContext}

// Import parameter validation helper and error handling
import dream/http.{require_string}
import dream/http/error

// Import request types
import dream/http/request.{type Request, Get}

// Import response types and builders
import dream/http/response.{type Response, text_response}

// Import HTTP status codes
import dream/http/status.{bad_request, ok}

// Import routing helpers
import dream/router.{type EmptyServices, route, router as create_router}

// Import server setup functions
import dream/servers/mist/server.{bind, listen, router}

// Import Gleam standard library
import gleam/int
import gleam/io
import gleam/result

// Middleware: Functions that wrap controllers
// Signature: (Request, Context, Services, NextFunction) -> Response
// This logging middleware demonstrates how middleware wraps controllers:
// 1. Code runs BEFORE the controller (request flows in)
// 2. Call `next()` to invoke the controller
// 3. Code runs AFTER the controller (response flows out)
fn logging_middleware(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
  next: fn(Request, EmptyContext, EmptyServices) -> Response,
) -> Response {
  // Code here runs BEFORE the controller
  io.println("Incoming request: " <> request.path)

  // Call the next middleware or controller
  let response = next(request, context, services)

  // Code here runs AFTER the controller
  io.println("Completed with status: " <> int.to_string(response.status))

  // Return the response (we can modify it here if needed)
  response
}

// Controller: A function that handles HTTP requests
// Signature: (Request, Context, Services) -> Response
// Controllers extract parameters, do work, and return responses
fn handle_echo(
  request: Request,
  _context: EmptyContext,
  // Underscore prefix means "unused"
  _services: EmptyServices,
) -> Response {
  // Use a result block to chain operations that return Result types
  let result = {
    // Extract and validate the "message" parameter from the URL
    // require_string returns Result(String, Error)
    use message <- result.try(require_string(request, "message"))
    Ok(message)
  }

  // Pattern match on the result to build the appropriate response
  case result {
    Ok(message) -> text_response(ok, "Hello, " <> message <> "!")
    Error(error) -> text_response(bad_request, error.message)
  }
}

// Main entry point: Set up and start the web server
pub fn main() {
  // Create a router with one route
  // The route has a path parameter `:message` that gets extracted automatically
  let app_router =
    create_router()
    |> route(
      method: Get,
      // Only match GET requests
      path: "/echo/:message",
      // :message is a path parameter
      controller: handle_echo,
      // Function to call when route matches
      middleware: [logging_middleware],
      // Middleware wraps the controller
    )

  // Configure and start the server using the builder pattern
  server.new()
  // Defaults to EmptyContext and EmptyServices - perfect for simple apps!
  |> router(app_router)
  // Use the router we created above
  |> bind("localhost")
  // Listen on localhost only
  |> listen(3000)
  // Start listening on port 3000
}
```

**Run this:** `gleam run` → Visit `http://localhost:3000/echo/World` → See `Hello, World!`  
**Middleware logs:** Request path before, response status after. No configuration needed!

## Why This Approach?

**Everything is explicit.** You can see exactly where your database connection comes from. No globals, no hidden state, no framework magic.

**Controller actions are just functions.** No base classes, no decorators, no inheritance. Extract parameters, do work, return a response.

**Type-safe controllers.** The compiler verifies your context and services types match across all controllers. However, path parameters are validated at runtime, not compile-time—this trade-off favors API ergonomics over compile-time safety. See [Discussion #15](https://github.com/TrustBound/dream/discussions/15) for details.

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
