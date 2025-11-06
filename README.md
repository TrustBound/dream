# Dream

**Clean, composable web development for Gleam. No magic. No surprises.**

Dream is a web library that gets out of your way. Everything is explicit. Your `main()` function shows exactly what's happening—no framework deciding things for you behind the scenes.

## Why Dream?

Because you've debugged enough "helpful" frameworks at 2am.

Here's a complete web application:

```gleam
import dream/core/context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

That's it. No hidden configuration. No magic middleware appearing from nowhere. Everything you need to understand your app is right there in `main()`.

## What Makes Dream Different

| Traditional Framework | Dream |
|-----------------------|-------|
| `Framework.start()` <br/>*(What server? What config? ¯\\\_(ツ)_/¯)* | `dream.new() \|> router(...) \|> listen(3000)` <br/>*(Everything explicit)* |
| Magic middleware that runs... somewhere | Middleware listed in route definitions |
| Dependencies from ??? | Dependencies explicit in function signatures |
| Framework decides your structure | You decide your structure |
| Locked into "the framework way" | Mix and match as needed |

## Quick Start

### 1. Define Your Controller

Controllers are just functions. Extract what you need, do your work, return a response:

```gleam
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import examples/database/models/user
import examples/database/services.{type Services}
import gleam/int
import gleam/result

pub fn index(_request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  user.list(db) |> response.many_rows(user.encode_list)
}

pub fn create(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email) |> response.one_row(user.encode_create)
    }
  }
}
```

No boilerplate. No ceremony. Just logic.

### 2. Configure Your Routes

```gleam
import dream/core/router.{route, router}
import dream/core/http/transaction.{Get, Post}
import examples/database/controllers/users_controller as users

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(method: Get, path: "/users", controller: users.index, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: users.show, middleware: [])
  |> route(method: Post, path: "/users", controller: users.create, middleware: [])
}
```

### 3. Define Your Model

Models handle data operations. Controllers handle HTTP. Clean separation:

```gleam
import dream/utilities/json/encoders
import examples/database/sql
import gleam/dynamic/decode
import gleam/json
import pog

// Query functions - wrap Squirrel SQL, return Results
pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

// Request decoder for validation
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

// JSON encoder for responses
pub fn encode(user: sql.GetUserRow) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
    #("created_at", encoders.timestamp(user.created_at)),
  ])
}
```

Your model returns `Result` types. Your controller returns `Response` types. The framework helpers bridge the gap. Simple.

## Core Features

- **🎯 Simple Controllers**: Extract params → validate → call model → respond
- **📦 Model Pattern**: Queries, encoders, decoders in one place
- **✅ Built-in Validation**: JSON validation with clear error messages
- **🗄️ PostgreSQL Support**: Type-safe queries with Squirrel, connection pooling
- **🔧 Builder Patterns**: Consistent API across server, router, client
- **🛡️ Type Safety**: Compile-time guarantees, not runtime surprises
- **🚫 No Closures**: All dependencies explicit—no hidden state

## Three-Layer Architecture

Dream uses a simple three-layer pattern that keeps controllers clean:

```gleam
// Layer 1: Controller (HTTP orchestration)
pub fn create(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email) |> response.one_row(user.encode_create)
    }
  }
}

// Layer 2: Model (data operations)
pub fn create(db, name, email) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError)
pub fn decoder() -> decode.Decoder(#(String, String))
pub fn encode_create(user: sql.CreateUserRow) -> json.Json

// Layer 3: Utilities (framework helpers)
// dream/validators/json_validator - Validate JSON bodies
// dream/services/postgres/response - Convert Results to Responses
// dream/utilities/json/encoders - Common JSON encoders
```

**Result:** Controllers are 50%+ smaller and actually readable.

## Database Setup

Dream includes PostgreSQL support with type-safe queries via [Squirrel](https://github.com/giacomocavalieri/squirrel):

```bash
make db-up      # Start PostgreSQL in Docker
make migrate    # Run migrations
```

Connection: `postgres://postgres:postgres@localhost:5434/dream_db`

See `src/examples/database/` for complete CRUD examples.

## Documentation

**Getting Started:**
- 📘 [Getting Started Guide](docs/getting-started.md) - Your first Dream app
- 📗 [Tutorial: Basic Routing](docs/tutorials/basic-routing.md) - Routes and path parameters
- 📙 [Tutorial: Database CRUD](docs/tutorials/database-crud.md) - Full CRUD with PostgreSQL
- 📕 [Tutorial: Authentication](docs/tutorials/authentication.md) - Custom context and middleware
- 📓 [Tutorial: HTTP Client](docs/tutorials/http-client.md) - Making HTTP requests

**Guides:**
- [Controllers and Models](docs/guides/controllers-and-models.md) - Three-layer architecture in depth
- [Middleware](docs/guides/middleware.md) - Writing and using middleware
- [Testing](docs/guides/testing.md) - Unit and integration testing
- [Database](docs/guides/database.md) - PostgreSQL, migrations, Squirrel
- [Deployment](docs/guides/deployment.md) - Running in production

**Reference:**
- [Architecture](docs/reference/architecture.md) - How it all fits together
- [Design Principles](docs/reference/design-principles.md) - The "why" behind decisions
- [API Reference](docs/reference/api-reference.md) - Complete API documentation
- [Naming Conventions](docs/reference/naming-conventions.md) - For contributors

**Examples:**
- [Example Projects](docs/examples.md) - Overview of all examples
- `src/examples/simple/` - Basic routing
- `src/examples/database/` - Full CRUD with PostgreSQL
- `src/examples/custom_context/` - Authentication with custom context
- `src/examples/singleton/` - Rate limiting with global state using the singleton pattern
- `src/examples/streaming/` - HTTP client streaming

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

Because finding where that database connection came from shouldn't require a treasure map.

## Installation

Add Dream to your `gleam.toml`:

```toml
[dependencies]
dream = ">= 0.0.1"
```

For database support, also add:

```toml
[dependencies]
pog = ">= 4.0.0"
squirrel = ">= 4.0.0"
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT License](LICENSE.md)

---

*Built with Gleam. Runs on the BEAM. Works like you'd expect.*
