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
import dream/core/context.{AppContext}
import dream/servers/mist/server as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
  dream.new()
  |> dream.context(AppContext(request_id: ""))
  |> dream.services(initialize_services())
  |> dream.router(create_router())
  |> dream.bind("localhost")
  |> dream.listen(3000)
}
```

**Router Configuration**:
```gleam
import dream/core/router.{EmptyServices, Router, route, router}
import dream/core/http/transaction.Get
import dream/core/context.{AppContext}

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    handler: home_controller.index,
    middleware: [],
  )
}
```

**Handler Signature**:
```gleam
import dream/core/http/transaction.{Request, Response}
import dream/core/context.{AppContext}

pub fn index(
  request: Request,
  context: AppContext,
  services: Services,
) -> Response {
  // Handler logic here
}
```

Everything is explicit. No magic. No vendor lock-in.

## Documentation

- **[Design Principles](documentation/DESIGN_PRINCIPLES.md)** - The "why" behind every architectural decision
- **[Architecture Overview](documentation/ARCHITECTURE.md)** - Big picture explanation
- **[Naming Conventions](documentation/NAMING_CONVENTIONS.md)** - Function naming guidelines
- **[Examples](src/examples/)** - Real-world usage patterns:
  - `simple/` - Basic routing with default AppContext
  - `streaming/` - HTTP client streaming example
  - `custom_context/` - Custom context with authentication middleware

## What Makes Dream Different?

### Traditional Framework
```gleam
// Where's the router? What server? Hidden!
Framework.start()
```

### Dream (Composable Library)
```gleam
import dream/core/context.{AppContext}
import dream/servers/mist/server as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

// Everything explicit - builder pattern shows exactly what's configured
dream.new()
  |> dream.context(AppContext(request_id: ""))
  |> dream.services(initialize_services())
  |> dream.router(create_router())
  |> dream.bind("localhost")
  |> dream.listen(3000)
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
   - `examples/simple/` - Basic routing and HTTP client usage with default AppContext
   - `examples/streaming/` - Streaming HTTP requests
   - `examples/custom_context/` - Custom context types with authentication middleware
   - `examples/database/` - Database integration with PostgreSQL service pattern

## Database Setup

Dream includes PostgreSQL support via the `pog` library and uses `cigogne` for database migrations. To run a local PostgreSQL database for development:

```bash
# Start PostgreSQL container
make db-up

# Stop PostgreSQL container
make db-down

# View database logs
make db-logs

# Access PostgreSQL shell
make db-shell

# Reset database (removes all data)
make db-reset

# Run migrations (applies all pending migrations)
make migrate

# Apply next migration
make migrate-up

# Rollback last migration
make migrate-down

# Create a new migration
make migrate-new name=my_migration_name
```

The database will be available at:
- **Host**: `localhost`
- **Port**: `5434`
- **Database**: `dream_db`
- **User**: `postgres`
- **Password**: `postgres`
- **Connection URL**: `postgres://postgres:postgres@localhost:5434/dream_db`

Migrations are stored in `priv/migrations/` and are automatically applied when the example app starts. See `src/dream/services/postgres.gleam` for the PostgreSQL service implementation using the singleton pattern, and `src/examples/database/database.gleam` for migration integration.

## Key Features

- **Middleware Chaining**: Full middleware support with chaining and execution
- **Type-Safe Context**: Generic context system for custom request context types
- **Rails-Style Controllers**: Controller actions like `index`, `show`, `fetch`
- **Builder Patterns**: Consistent fluent API across server, router, and client

## License

[MIT License](LICENSE.md)
