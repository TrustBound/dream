# Dream

**A composable web library for Gleam/BEAM**

Dream is not an opinionated framework. It's a collection of clean interfaces, builder patterns, and building blocks that you compose however you want.

## Philosophy

**We provide**: Clean interfaces, common patterns, and reference implementations.  
**You decide**: Which router to use, which server to use, how to structure everything.

- ✅ **Builder patterns**: Consistent fluent API across server, router, and client
- ✅ **No closures**: All functions use explicit parameter passing  
- ✅ **No magic**: Everything is explicit in your `main()` function
- ✅ **No vendor lock-in**: Never trapped by our choices
- ✅ **Mix and match**: Use Dream's router with your server, or vice versa

## Quick Example

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
import dream/core/router.{type Router, add_route, handler, method, new as route, path, router}
import dream/core/http/transaction.Get

pub fn create_router() -> Router {
  router
  |> add_route(
    route
    |> method(Get)
    |> path("/")
    |> handler(home_controller),
  )
}
```

Everything is explicit. No magic. No vendor lock-in.

## Documentation

- **[Design Principles](documentation/DESIGN_PRINCIPLES.md)** - The "why" behind every architectural decision
- **[Architecture Overview](documentation/ARCHITECTURE.md)** - Big picture explanation
- **[Naming Conventions](documentation/NAMING_CONVENTIONS.md)** - Function naming guidelines
- **[Examples](src/examples/)** - Real-world usage patterns (simple and streaming examples)

## What Makes Dream Different?

### Traditional Framework
```gleam
// Where's the router? What server? Hidden!
Framework.start()
```

### Dream (Composable Library)
```gleam
import dream/servers/mist/server.{bind, listen, router} as dream

// Everything explicit - builder pattern shows exactly what's configured
dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
```

## Core Principles

1. **Builder Pattern Consistency** - Server, router, and client all use the same fluent API style
2. **No Closures** - Explicit parameter passing only
3. **Result-Based Errors** - All failable operations return `Result(success, error)`
4. **Type Safety First** - Leverage Gleam's type system
5. **Explicit Composition** - Your `main()` shows exactly what's wired together
6. **Modular Design** - HTTP client split into logical modules

## Getting Started

1. Read [Design Principles](documentation/DESIGN_PRINCIPLES.md) to understand the philosophy
2. Check [documentation/ARCHITECTURE.md](documentation/ARCHITECTURE.md) for the big picture
3. Look at [examples](src/examples/) for real-world usage:
   - `examples/simple/` - Basic routing and HTTP client usage
   - `examples/streaming/` - Streaming HTTP requests

## License

[MIT License](LICENSE.md)
