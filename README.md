# Dream

**Clean, composable web development for Gleam**

Dream is a web library that gets out of your way. No magic. No hidden behavior. Just clean patterns and composable building blocks.

## Why Dream?

```gleam
// This is a complete web application
pub fn main() {
  dream.new()
  |> dream.context(AppContext(request_id: ""))
  |> dream.services(initialize_services())
  |> dream.router(create_router())
  |> dream.bind("localhost")
  |> dream.listen(3000)
}
```

**Everything is explicit.** You see exactly what's configured. No framework magic deciding things for you.

## Quick Start

### 1. Define Your Controller

Controllers are simple functions:

```gleam
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

Clean. Simple. No boilerplate.

### 2. Configure Your Routes

```gleam
pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(method: Get, path: "/users", controller: users.index, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: users.show, middleware: [])
  |> route(method: Post, path: "/users", controller: users.create, middleware: [])
}
```

### 3. Define Your Model

Models handle data operations:

```gleam
// examples/database/models/user.gleam

pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

pub fn encode(user: sql.GetUserRow) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}
```

That's it. Your model handles queries and encoding. Your controller handles HTTP. Clean separation.

## What Makes Dream Different

| Traditional Framework | Dream |
|----------------------|-------|
| `Framework.start()` | You compose: `dream.new() \|> router(...) \|> listen(3000)` |
| Magic middleware | Explicit middleware in route definitions |
| Hidden dependencies | Dependencies explicit in function signatures |
| Framework decides structure | You decide structure |
| Locked into framework patterns | Mix and match as needed |

## Core Features

- **🎯 Simple Controllers**: Extract params → validate → call model → respond
- **📦 Model Pattern**: Queries, encoders, decoders in one place
- **✅ Built-in Validation**: JSON validation with detailed error messages
- **🗄️ PostgreSQL Support**: Type-safe queries with Squirrel, connection pooling
- **🔧 Builder Patterns**: Consistent API across server, router, client
- **🛡️ Type Safety**: Compile-time guarantees, no runtime surprises
- **🚫 No Closures**: All dependencies explicit - no hidden state

## Documentation

**Getting Started:**
- 📘 [Architecture Overview](documentation/ARCHITECTURE.md) - Understand how it all fits together
- 📗 [Controller Patterns](documentation/CONTROLLER_PATTERNS.md) - Build clean, simple controllers
- 📙 [Design Principles](documentation/DESIGN_PRINCIPLES.md) - The "why" behind decisions

**Reference:**
- 📕 [Naming Conventions](documentation/NAMING_CONVENTIONS.md) - Consistent function naming

**Examples:**
- `examples/simple/` - Basic routing
- `examples/database/` - Full CRUD with PostgreSQL
- `examples/custom_context/` - Authentication with custom context
- `examples/streaming/` - HTTP client streaming

## Controller Pattern

Dream uses a **three-layer architecture** that keeps controllers ultra-clean:

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
// examples/database/models/user.gleam
pub fn create(db, name, email) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError)
pub fn decoder() -> decode.Decoder(#(String, String))
pub fn encode_create(user: sql.CreateUserRow) -> json.Json

// Layer 3: Utilities (framework helpers)
// dream/services/postgres/response - Convert Results to Responses
// dream/validators/json_validator - Validate JSON bodies
// dream/utilities/json/encoders - Common JSON encoders
```

**Result:** Controllers are 50%+ smaller, highly readable, and follow consistent patterns.

## Database Setup

Dream includes PostgreSQL support with type-safe queries via [Squirrel](https://github.com/giacomocavalieri/squirrel):

```bash
make db-up      # Start PostgreSQL in Docker
make migrate    # Run migrations
```

Connection details:
- URL: `postgres://postgres:postgres@localhost:5434/dream_db`

See `examples/database/` for complete CRUD examples with models and controllers.

## Philosophy

Dream is **explicitly not a framework**. We provide:

✅ Clean interfaces and types  
✅ Common patterns (controllers, models, middleware)  
✅ Useful utilities (validation, response builders)  
✅ Great examples

You provide:

🎯 Your application structure  
🎯 Your router configuration  
🎯 Your controllers and models  
🎯 Your business logic  

**No magic. No hidden behavior. Everything explicit.**

## License

[MIT License](LICENSE.md)
