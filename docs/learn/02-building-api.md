# Lesson 2: Building an API

**Time:** 45 minutes  
**Goal:** Build a REST API with database, learn Services, and organize code

You'll build a complete CRUD API for users with PostgreSQL, including database setup, migrations, and type-safe SQL queries.

## What You'll Learn

- How to add a database connection (Services)
- Path parameters for dynamic routes (`:id`)
- Database migrations with Cigogne
- Type-safe SQL with Squirrel
- When to split code into models and views
- Why models (write path) and views (read path) are separate

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

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Step 3: Create Makefile

Create `Makefile`:

```makefile
DATABASE_URL = postgres://postgres:postgres@localhost:5432/myapp

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

**Why a Makefile?** Instead of remembering `gleam run -m squirrel`, `gleam run -m cigogne all`, `docker-compose up`, etc., you just run `make db-up`, `make migrate`, `make squirrel`. One command, no thinking.

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

This creates the `users` table in your database.

## Step 6: Create SQL Queries

Create `sql/create_user.sql`:

```sql
-- name: create_user
INSERT INTO users (name, email)
VALUES ($1, $2)
RETURNING id, name, email, created_at;
```

Create `sql/get_user.sql`:

```sql
-- name: get_user
SELECT id, name, email, created_at
FROM users
WHERE id = $1;
```

Create `sql/list_users.sql`:

```sql
-- name: list_users
SELECT id, name, email, created_at
FROM users
ORDER BY created_at DESC;
```

### Generate Type-Safe Gleam Code

```bash
make squirrel
```

This creates `src/sql.gleam` with type-safe functions: `create_user()`, `get_user()`, `list_users()`.

**Why Squirrel?** Instead of writing raw SQL strings and parsing results manually, Squirrel generates Gleam functions with types. The compiler catches SQL errors at compile time.

## Step 7: Define Services

Create `src/services.gleam`:

```gleam
import gleam/erlang/process.{new_name}
import gleam/option.{Some}
import gleam/otp/actor.{Started}
import pog.{Connection, default_config, host, port, database, user, password, pool_size, start}

pub type Services {
  Services(db: Connection)
}

pub fn initialize_services() -> Services {
  let pool_name = new_name("db_pool")
  
  let config =
    default_config(pool_name: pool_name)
    |> host("localhost")
    |> port(5432)
    |> database("myapp")
    |> user("postgres")
    |> password(Some("postgres"))
    |> pool_size(10)
  
  let assert Ok(Started(_pid, connection)) = start(config)
  
  Services(db: connection)
}
```

**What's happening here:**

1. `Services` type holds the database connection
2. `initialize_services()` creates the connection pool
3. This runs once when the server starts
4. Every controller gets access to `services.db`

**Why Services?**

In Lesson 1, we used `EmptyServices` because we had no database. Now we need to pass the database connection to controllers.

Without Services, you'd need:
- Global variables (can't do safely in Gleam)
- Process dictionary (Erlang hack, not type-safe)
- Threading `db` through manually (tedious, error-prone)

Services solves this with type safety. The compiler verifies every controller gets the connection it needs.

## Step 8: Create Types

Create `src/types/user.gleam`:

```gleam
import gleam/time/timestamp.{type Timestamp}

pub type User {
  User(
    id: Int,
    name: String,
    email: String,
    created_at: Timestamp,
  )
}
```

This is our domain type - the shape of data our app works with.

## Step 9: Create the Model

Create `src/models/user.gleam`:

```gleam
import types/user.{type User}
import sql
import gleam/list.{type List, map}
import gleam/option.{unwrap}
import gleam/time/timestamp.{system_time}
import gleam/dynamic/decode.{type Decoder, field, string, success}
import gleam/result.{try}
import pog.{type Connection, type Returned}

import dream/http/error.{type Error, NotFound, InternalServerError}

pub fn list(db: Connection) -> Result(List(User), Error) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(map(returned.rows, row_to_user))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

pub fn get(db: Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

pub fn create(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.create_user(db, name, email) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

pub fn decoder() -> Decoder(#(String, String)) {
  use name <- field("name", string)
  use email <- field("email", string)
  success(#(name, email))
}

fn extract_first_user(
  returned: Returned(sql.GetUserRow),
) -> Result(User, Error) {
  case returned.rows {
    [row] -> Ok(row_to_user(row))
    [] -> Error(NotFound("User not found"))
    _ -> Error(NotFound("User not found"))
  }
}

fn row_to_user(row: sql.GetUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: unwrap(row.created_at, system_time()),
  )
}
```

**What's happening here:**

1. Models handle data access - getting data from the database
2. They take `db: Connection` explicitly (no globals)
3. They return domain types (`User`), not database types
4. They handle the conversion from DB rows to domain types internally

**Why a separate model?**

Models are the **write path** - handling incoming data and persistence:
- Accept what data we need (`decoder()`)
- Validate and store it (`create()`)
- Retrieve it (`get()`, `list()`)
- Convert DB rows → domain types

This keeps database concerns in one place.

## Step 10: Create the View

Create `src/views/user_view.gleam`:

```gleam
import types/user.{type User}
import gleam/int.{to_string}
import gleam/json
import gleam/list.{type List, map}

pub fn to_json(user: User) -> String {
  user_to_json_object(user)
  |> json.to_string()
}

pub fn list_to_json(users: List(User)) -> String {
  map(users, user_to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

fn user_to_json_object(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}

fn identity(x: a) -> a {
  x
}
```

**What's happening here:**

Views handle presentation - formatting data for output.

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

Create `src/controllers/users_controller.gleam`:

```gleam
import dream/context.{type AppContext}
import dream/http.{require_int, type Request, type Response, json_response, ok, created, validate_json}
import gleam/result
import models/user.{list, get, create, decoder}
import services.{type Services}
import utilities/response_helpers
import views/user_view.{to_json, list_to_json}

pub fn index(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    list(db)
  }
  
  case result {
    Ok(users) -> json_response(ok, list_to_json(users))
    Error(err) -> response_helpers.handle_error(err)
  }
}

pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    get(db, id)
  }
  
  case result {
    Ok(user_data) -> json_response(ok, to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

pub fn create(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use data <- result.try(validate_json(request.body, decoder()))
    let #(name, email) = data
    let db = services.database.connection
    create(db, name, email)
  }
  
  case result {
    Ok(user_data) -> json_response(created, to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

**What's happening here:**

Controllers orchestrate the flow:
1. Extract and validate path parameters using `require_int` (returns `Result` for safe handling)
2. Call models for data access (models return `Result(_, dream.Error)`)
3. Handle errors uniformly through `response_helpers.handle_error` (maps `dream.Error` to HTTP responses)
4. Call views for formatting

**Why this pattern?**

- **`require_int`**: Safely extracts and validates path parameters. Returns `BadRequest` if missing or invalid, eliminating the need for `let assert`.
- **Flat `use` chains**: The `use` syntax keeps code readable without nested `case` statements.
- **Unified errors**: All errors use `dream.Error`, so controllers don't need to map between different error types.
- **Centralized error handling**: `response_helpers.handle_error` ensures consistent error responses across the application.
5. Build responses

**The require_* pattern (recommended):**

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

Create `src/router.gleam`:

```gleam
import dream/http.{Get, Post}
import dream/router.{type Router, route, router}
import dream/context.{type AppContext}
import controllers/users_controller.{index, show, create}
import services.{type Services}

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(method: Get, path: "/users", controller: index, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: show, middleware: [])
  |> route(method: Post, path: "/users", controller: create, middleware: [])
}
```

Notice the type: `Router(AppContext, Services)`

This tells the compiler:
- Routes must use AppContext for context
- Routes must use Services for services
- Every controller must have signature: `fn(Request, AppContext, Services) -> Response`

Type safety across your entire app.

## Step 13: Wire It Together

Update `src/main.gleam`:

```gleam
import dream/servers/mist/server.{bind, listen, new, router, services} as server
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  server.new()
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

**Note:** When using Dream's default `AppContext`, you don't need to call `context()` - it's automatic.

## Run It

```bash
make run
```

Test it:

```bash
# List users
curl http://localhost:3000/users

# Create user
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

# Get specific user
curl http://localhost:3000/users/1
```

## Code Organization

You now have:

```
src/
├── main.gleam           # Server setup
├── router.gleam         # Route definitions
├── services.gleam       # Database connection
├── sql.gleam            # Generated from Squirrel
├── types/
│   └── user.gleam       # Domain type
├── models/
│   └── user.gleam       # Data access (write path)
├── views/
│   └── user_view.gleam  # Presentation (read path)
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
✅ Context = per-request data (still default for now)  
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
