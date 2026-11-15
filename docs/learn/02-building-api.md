# Lesson 2: Building an API

**Goal:** Build a REST API with database, learn Services, and organize code

You'll build a complete CRUD API for users with PostgreSQL, including database setup, migrations, and type-safe SQL queries.

## What You'll Learn

This lesson assumes you have written the "Hello world" server from
Lesson 1 and are comfortable running `gleam run`.

By the end, you will know how to:

- Add a database connection using a typed `Services` value.
- Use path parameters for dynamic routes (`:id`).
- Run database migrations with Cigogne.
- Generate type-safe SQL helpers with Squirrel.
- Split code into models and views and understand **why** that
  separation matters.

## Prerequisites

- [Lesson 1: Hello World](01-hello-world.md) completed
- Docker installed (for PostgreSQL)

## Setup

### Step 1: Add Dependencies

```bash
gleam add pog squirrel cigogne
```

- `pog` - PostgreSQL driver for Gleam
- `squirrel` - Generates type-safe Gleam from SQL files
- `cigogne` - Database migrations

### Step 2: Create Docker Compose

Create `docker-compose.yml`. This is the file from `examples/database`:

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:16-alpine
    container_name: dream_example_database_postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: dream_example_database_db
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5435:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
```

The database listens on port 5435 on your machine, so it does not collide with another PostgreSQL on port 5432.

### Step 3: Create Makefile

Create `Makefile`:

```makefile
DATABASE_URL = postgres://postgres:postgres@localhost:5435/dream_example_database_db

.PHONY: run test clean db-up db-down db-reset migrate migrate-up migrate-down migrate-new squirrel

run:
	@gleam run -m main

test:
	@gleam test

clean:
	@gleam clean

# Docker Compose commands
db-up:
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

db-down:
	@docker-compose down

db-reset:
	@docker-compose down -v
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

# Generate type-safe SQL code with Squirrel
squirrel:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m squirrel

# Migration commands using cigogne
migrate:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all

migrate-up:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne up

migrate-down:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne down

migrate-new:
	@gleam run -m cigogne new --name $(name)
```

**Why a Makefile?** Instead of remembering `gleam run -m squirrel`,
`gleam run -m cigogne all`, `docker-compose up`, etc., you just run
`make db-up`, `make migrate`, `make squirrel`. One command, no
thinking.

If you are new to Makefiles, you can think of each name (`run`,
`db-up`, `migrate`) as a **shortcut** for a longer command. You do not
need to know all of Make, you just need to know which shortcut to call
for common tasks.

### Step 4: Start Database

```bash
make db-up
```

## Step 5: Create Database Schema

### Create Migration

```bash
make migrate-new name=create_users
```

This creates a file like `priv/migrations/20250101120000-create_users.sql`. Edit it:

```sql
--- migration:up
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
--- migration:down
DROP TABLE IF EXISTS users;
--- migration:end
```

### Run Migration

```bash
make migrate
```

This creates the `users` table in your database. The migration in
`examples/database` also creates a `posts` table, which this lesson
does not use.

## Step 6: Create SQL Queries

Create `sql/create_user.sql`:

```sql
-- Create a new user
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at
```

Create `sql/get_user.sql`:

```sql
-- Get a single user by ID
SELECT id, name, email, created_at FROM users WHERE id = $1
```

Create `sql/list_users.sql`:

```sql
-- List all users
SELECT id, name, email, created_at FROM users ORDER BY id
```

Squirrel names each function after its file.

### Generate Type-Safe Gleam Code

```bash
make squirrel
```

This creates `src/sql.gleam` with type-safe functions: `create_user()`, `get_user()`, `list_users()`.

**Why Squirrel?** Instead of writing raw SQL strings and parsing results manually, Squirrel generates Gleam functions with types. The compiler catches SQL errors at compile time.

## Step 7: Define Services

Services hold the things that every request shares, such as the
database connection pool. The app in `examples/database` puts the pool
in three small files.

First, create `src/database.gleam`. It starts the connection pool:

### Starting the connection pool <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/database.gleam#L7-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import pog

pub type DatabaseService {
  DatabaseService(connection: pog.Connection)
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    pog.default_config(pool_name: pool_name)
    |> pog.host("localhost")
    |> pog.port(5435)
    |> pog.database("dream_example_database_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)

  // Start the connection pool
  case pog.start(config) {
    Ok(actor.Started(_pid, connection)) -> {
      Ok(DatabaseService(connection: connection))
    }
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  }
}
```

Then create `src/services.gleam`. It holds the database service:

### Services with a database service <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/services.gleam#L5-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import database.{type DatabaseService}

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
/// Uses assert to panic if initialization fails - adjust for production use
pub fn initialize_services() -> Services {
  let assert Ok(database_service) = database.init_database()
  Services(database: database_service)
}
```

Last, create `src/context.gleam`. Context holds per-request data.
This app keeps only a request ID in it:

### A small context type <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/context.gleam#L5-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Database context for tracking per-request state
pub type DatabaseContext {
  DatabaseContext(request_id: String)
}

/// Template context with empty request_id
/// The request_id will be updated for each request
pub const context = DatabaseContext(request_id: "")
```

**What's happening here:**

1. `init_database()` builds a configuration for Pog (the PostgreSQL
   driver) and starts a connection pool. Starting the pool can fail, so
   `init_database()` returns a `Result`.
2. `initialize_services()` runs once when the server starts. If the
   database is not available, `let assert` stops the app at startup.
   Change this for production use.
3. Every controller gets `services` as an argument, and reads the pool
   from `services.database.connection`.
4. `DatabaseContext` is a custom context with one field. Lesson 3
   explains custom context in full.

**Why Services?**

In Lesson 1, we used `EmptyServices` because we had no database. Now we need to pass the database connection to controllers.

Without Services, you'd need:
- Global variables (can't do safely in Gleam)
- Process dictionary (Erlang hack, not type-safe)
- Threading `db` through manually (tedious, error-prone)

Services solves this with type safety. The compiler verifies every controller gets the connection it needs.

## Step 8: Create Types

Create `src/types/user.gleam`:

### The User type <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/learn_building_api_user.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/time/timestamp.{type Timestamp}

pub type User {
  User(id: Int, name: String, email: String, created_at: Timestamp)
}
```

This is our domain type - the shape of data our app works with.

## Step 9: Create the Model

Create `src/models/user.gleam`. The model has one function for each
database action:

### The user model <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/models/user.gleam#L6-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{type Error, InternalServerError, NotFound}
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog
import sql
import types/user.{type User, User}

/// List all users
pub fn list(db: pog.Connection) -> Result(List(User), Error) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(extract_all_users(returned))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Get a single user by ID
pub fn get(db: pog.Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Create a new user
pub fn create(
  db: pog.Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.create_user(db, name, email) {
    Ok(returned) -> extract_created_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Update a user
pub fn update(
  db: pog.Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.update_user(db, name, email, id) {
    Ok(returned) -> extract_updated_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Delete a user
pub fn delete(db: pog.Connection, id: Int) -> Result(Nil, Error) {
  case sql.delete_user(db, id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Decoder for user create/update requests
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}
```

Squirrel makes one row type for each query, for example
`sql.GetUserRow` and `sql.ListUsersRow`. Thus the model has one small
function for each row type that converts the row to a `User`:

### Converting rows to users <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/models/user.gleam#L107-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn row_to_user(row: sql.GetUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_user_list(row: sql.ListUsersRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}
```

The other helpers in the file (`extract_first_user`,
`extract_all_users`, `extract_created_user`, `extract_updated_user`,
`row_to_user_create` and `row_to_user_update`) follow the same form.
See the [full model](https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/models/user.gleam).

**What's happening here:**

1. Models handle data access – getting data from the database.
2. They take `db: Connection` explicitly (no globals).
3. They return domain types (`User`), not database row structs.
4. They convert from DB rows to domain types inside helper functions
   like `row_to_user`.

If you are new to Gleam’s `Result` and pattern matching: each `case` on
`sql.*` checks whether the query succeeded (`Ok`) or failed (`Error`)
and then wraps database errors in the unified `dream.Error` type.

**Why a separate model?**

Models are the **write path** - handling incoming data and persistence:
- Accept what data we need (`decoder()`)
- Validate and store it (`create()`)
- Retrieve it (`get()`, `list()`)
- Convert DB rows → domain types

This keeps database concerns in one place.

### Add an operations module

The controller in the next steps does not call the model directly. It
calls `src/operations/user_operations.gleam`. In this app, each
operation passes the call to the model:

### User operations <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/operations/user_operations.gleam#L6-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{type Error}
import models/user as user_model
import pog.{type Connection}
import types/user.{type User}

/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  user_model.get(db, id)
}

/// List all users
pub fn list_users(db: Connection) -> Result(List(User), Error) {
  user_model.list(db)
}

/// Create a new user
pub fn create_user(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  user_model.create(db, name, email)
}
```

The file also has `update_user` and `delete_user`. An operation is the
place for business logic that uses more than one model. Lesson 4
explains when an operation earns its place.

## Step 10: Create the View

Create `src/views/user_view.gleam`:

### The user view <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/learn_building_api_user_view.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/json
import snippets/learn_building_api_user.{type User}

pub fn to_json(user: User) -> String {
  user_to_json_object(user)
  |> json.to_string()
}

pub fn list_to_json(users: List(User)) -> String {
  json.array(users, user_to_json_object)
  |> json.to_string()
}

fn user_to_json_object(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}
```

The tested snippet imports `User` from `snippets/learn_building_api_user`.
In your app, import it from the `types/user` module.

**What's happening here:**

Views handle presentation – formatting data for output as JSON strings.
They know **nothing** about how data is stored.

**Why separate from models?**

Views are the **read path** - formatting domain types for responses:
- Take domain types (`User`)
- Return formatted output (`String`)
- No database knowledge
- No error handling (that's the controller's job)

This separation means:
- Change database schema → update models only
- Add new output format (HTML, CSV) → update views only
- Controllers just orchestrate: model → view → response

## Step 11: Create the Controller

Create `src/controllers/users_controller.gleam`. Here are its
imports, a helper that decodes the request body, and the first three
actions:

### The users controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/controllers/users_controller.gleam#L6-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int}
import dream/http/error.{type Error, BadRequest}
import dream/http/response.{json_response}
import dream/http/status
import dream/http/validation.{validate_json}
import gleam/result
import models/user
import operations/user_operations
import services.{type Services}
import utilities/response_helpers
import views/user_view

fn parse_user_data(body: String) -> Result(#(String, String), Error) {
  case validate_json(body, user.decoder()) {
    Ok(d) -> Ok(d)
    Error(_) -> Error(BadRequest("Invalid user data"))
  }
}

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    user_operations.list_users(db)
  }

  case result {
    Ok(users) -> json_response(status.ok, user_view.list_to_json(users))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    user_operations.get_user(db, id)
  }

  case result {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use data <- result.try(parse_user_data(request.body))
    let #(name, email) = data
    let db = services.database.connection
    user_operations.create_user(db, name, email)
  }

  case result {
    Ok(user_data) -> json_response(status.created, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

The full file also has `update` and `delete` actions, which use the
same form.

The controller uses `utilities/response_helpers.gleam`, which maps a
`dream.Error` to a response. Copy it, and the `views/errors.gleam`
that it uses, from
[examples/database](https://github.com/TrustBound/dream/tree/2.5.0/examples/database/src).

**What's happening here:**

Controllers orchestrate the flow:

1. Extract and validate path parameters using `require_int` (returns a
   `Result` instead of panicking).
2. Decode the JSON body with `parse_user_data`, which returns
   `BadRequest` if the body is not valid user data.
3. Call operations for data access (they return
   `Result(_, dream.Error)`).
4. Handle errors uniformly through `response_helpers.handle_error`
   (maps `dream.Error` to HTTP responses).
5. Call views for formatting, and build the response.

If you are new to the `use <- result.try(...)` pattern: it is Gleam’s
way of saying “if this step fails, stop here and return the error,
otherwise carry on”, without deeply nested `case` expressions.

**Why this pattern?**

- **`require_int`**: Safely extracts and validates path parameters. Returns `BadRequest` if missing or invalid, eliminating the need for `let assert`.
- **Flat `use` chains**: The `use` syntax keeps code readable without nested `case` statements.
- **Unified errors**: All errors use `dream.Error`, so controllers don't need to map between different error types.
- **Centralized error handling**: `response_helpers.handle_error` ensures consistent error responses across the application.

**The require_* pattern (recommended):**

#### Reading a path parameter <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/learn_building_api_show_user.gleam#L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    use id <- result.try(require_int(request, "id"))
```

This pattern:
- Safely extracts and validates path parameters
- Returns `Result` types for error handling
- Works with flat `use` chains to keep code readable
- Handles missing or invalid parameters gracefully

**Note:** While `let assert` is still valid for path parameters (since the router guarantees they exist), `require_*` functions are preferred as they provide better error messages and work consistently with the unified error handling pattern.

**No nested cases:** Each controller uses flat `use` chains and extracts helpers to keep the code readable.

## Step 12: Create the Router

Create `src/router.gleam`. Here are the imports and the five users
routes:

### The users routes <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/router.gleam#L1-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context.{type DatabaseContext}
import controllers/posts_controller
import controllers/users_controller
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{type Router, route, router}
import services.{type Services}

pub fn create_router() -> Router(DatabaseContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/users",
    controller: users_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id",
    controller: users_controller.show,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/users",
    controller: users_controller.create,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/users/:id",
    controller: users_controller.update,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/users/:id",
    controller: users_controller.delete,
    middleware: [],
  )
```

The router in `examples/database` goes on with three posts routes. If
you build only the users API, remove the `posts_controller` import and
end the pipeline after the last users route with a closing `}`.

Notice the type: `Router(DatabaseContext, Services)`

This tells the compiler:
- Routes must use DatabaseContext for context
- Routes must use Services for services
- Every controller must have signature: `fn(Request, DatabaseContext, Services) -> Response`

Type safety across your entire app.

## Step 13: Wire It Together

Update `src/main.gleam`:

### The main function <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/database/src/main.gleam#L10-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context as db_context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(db_context.context)
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3002)
}
```

**Note:** The app uses a custom context, so `main` gives the starting
value to the server with `context(db_context.context)`. The module is
imported `as db_context`, because the name `context` is also the
server function.

## Run It

```bash
make run
```

Test it:

```bash
# List users
curl http://localhost:3002/users

# Create user
curl -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

# Get specific user
curl http://localhost:3002/users/1
```

## Code Organization

You now have:

```
src/
├── main.gleam           # Server setup
├── router.gleam         # Route definitions
├── context.gleam        # Per-request data
├── database.gleam       # Connection pool
├── services.gleam       # Shared services
├── sql.gleam            # Generated from Squirrel
├── types/
│   └── user.gleam       # Domain type
├── models/
│   └── user.gleam       # Data access (write path)
├── operations/
│   └── user_operations.gleam  # Business logic
├── views/
│   ├── user_view.gleam  # Presentation (read path)
│   └── errors.gleam     # Error responses
├── utilities/
│   └── response_helpers.gleam  # dream.Error to response
└── controllers/
    └── users_controller.gleam  # HTTP handling
```

## When to Split Files

**Start with one file** (Lesson 1)  
When you add a database → split into:
- `services.gleam` - Connections
- `models/entity.gleam` - Data access
- `views/entity_view.gleam` - Presentation  
- `controllers/entity_controller.gleam` - HTTP

**Why this organization?**

- Models change when database schema changes
- Views change when output format changes
- Controllers change when HTTP API changes

Separating them means changes are isolated.

## What You Learned

✅ Services = shared dependencies (database, HTTP clients)  
✅ Context = per-request data (only a request ID for now)  
✅ Models = data access layer (write path: decode, validate, persist)  
✅ Views = presentation layer (read path: format, encode)  
✅ Controllers = orchestration (request → model → view → response)  
✅ Type safety = `Router(Context, Services)` verified by compiler  
✅ Makefile = automation for common tasks  
✅ Migrations = version-controlled database changes  
✅ Squirrel = type-safe SQL queries

## Next Lesson

Your API works, but there's no authentication. Anyone can create or delete users.

Continue to [Lesson 3: Adding Auth](03-adding-auth.md) to learn custom context and middleware.

---

**Working example:** See [examples/database/](../../examples/database/) for the complete runnable code.
