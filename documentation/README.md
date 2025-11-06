# Dream Documentation

Dream is a **composable web library** (not an opinionated framework) built on Gleam/BEAM. We provide clean interfaces, builder patterns, and building blocks. You compose them however you want.

## Core Philosophy

**We provide**: Clean interfaces, common patterns, and reference implementations.  
**You decide**: Which router to use, which server to use, how to structure your application.

**No vendor lock-in**: Everything uses consistent builder patterns and is composable.  
**No closures**: All functions use explicit parameter passing.  
**No magic**: Everything is explicit in your `main()` function.

## Essential Reading

1. **[Architecture Overview](ARCHITECTURE.md)** - Start here to understand Dream's composable design
2. **[Design Principles](DESIGN_PRINCIPLES.md)** - Complete design philosophy and rationale
3. **[Naming Conventions](NAMING_CONVENTIONS.md)** - Function naming guidelines for consistency
4. **[Unit Testing Guide](UNIT_TESTING.md)** - Unit testing standards and practices

## Examples

The `src/examples/` directory contains practical examples demonstrating:
- Basic routing and path parameters (`examples/simple/`)
- HTTP client usage for streaming and non-streaming requests (`examples/streaming/`)
- Real-world usage patterns

## Getting Started

```gleam
import dream/servers/mist/server.{bind, listen, router} as dream
import examples/simple/router.{create_router}
import gleam/erlang/process

pub fn main() {
  case
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
```

**Router Configuration**:
```gleam
import dream/core/router.{type Router, route, router}
import dream/core/http/transaction.{Get}
import examples/simple/controllers/simple_controller

pub fn create_router() -> Router {
  router
  |> route(
    method: Get,
    path: "/",
    controller: simple_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    controller: simple_controller.show,
    middleware: [],
  )
}
```

Everything is explicit. No magic. No vendor lock-in.

## Key Architectural Principles

- **Builder Pattern Consistency**: Server, router, and HTTP client all use the same fluent API style
- **No Closures**: All functions use explicit parameter passing
- **Result-Based Error Handling**: All failable operations return `Result(success, error)`
- **Type Safety First**: Strong typing throughout
- **Explicit Composition**: Your `main()` shows exactly what's wired together
- **Modular Design**: HTTP client split into logical modules (stream, fetch, internal)

## What Dream Provides

- Builder patterns for server, router, and HTTP client
- Mist HTTP server adapter
- HTTP client with streaming and non-streaming support
- Path parameter extraction
- HTTP status code helpers
- Cookie parsing utilities
- Middleware infrastructure (type and builder functions exist, execution not yet implemented)
- Helper functions and utilities
- Documentation and examples

## What You Provide

- **Controller functions** that handle requests
- **Router configuration** using the builder pattern
- **Application-specific** business logic
- **Custom middleware** functions (infrastructure exists, but middleware execution not yet implemented)

## Need Help?

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for the big picture
- Check [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) for the "why" behind decisions
- Review [CONTROLLER_PATTERNS.md](CONTROLLER_PATTERNS.md) for controller and model design
- Review [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) for function naming guidelines
- Read [UNIT_TESTING.md](UNIT_TESTING.md) for testing standards and practices
- Look at examples in `src/examples/` for real-world usage

