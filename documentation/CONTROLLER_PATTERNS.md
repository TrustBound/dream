# Controller Patterns in Dream

This document describes the recommended patterns for building controllers in Dream applications, focusing on simplicity, type safety, and separation of concerns.

## Overview

Dream controllers follow a **three-layer architecture**:

1. **Controllers**: HTTP orchestration (params, validation, responses)
2. **Models**: Data operations (queries, encoding, decoding)
3. **Utilities**: Reusable helpers (response builders, JSON encoders, validators)

## The Model-Controller Pattern

### Model Layer

Models encapsulate all data operations for a domain entity.

**Location**: `src/{app}/models/{entity}.gleam`

**Responsibilities**:
- Wrap database queries (Squirrel-generated SQL functions)
- Provide JSON encoders for database rows
- Provide request body decoders
- Return `Result` types (never `Response` types)

**Example** (`examples/database/models/user.gleam`):

```gleam
import dream/utilities/json/encoders
import examples/database/sql
import gleam/dynamic/decode
import gleam/json
import pog

/// Query functions - wrap Squirrel SQL, return Results
pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

pub fn get(db: pog.Connection, id: Int) -> Result(pog.Returned(sql.GetUserRow), pog.QueryError) {
  sql.get_user(db, id)
}

pub fn create(
  db: pog.Connection,
  name: String,
  email: String,
) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError) {
  sql.create_user(db, name, email)
}

/// Request decoder - validates and decodes JSON body
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

/// JSON encoders - convert database rows to JSON
pub fn encode(user: sql.GetUserRow) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
    #("created_at", encoders.timestamp(user.created_at)),
  ])
}

pub fn encode_list(user: sql.ListUsersRow) -> json.Json {
  // Same fields, different row type
  json.object([...])
}
```

### Controller Layer

Controllers handle HTTP concerns only.

**Location**: `src/{app}/controllers/{entity}_controller.gleam`

**Responsibilities**:
- Extract dependencies from services
- Parse path parameters
- Validate request bodies
- Call model functions
- Convert Results to HTTP Responses

**Example** (`examples/database/controllers/users_controller.gleam`):

```gleam
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import examples/database/models/user
import examples/database/services.{type Services}

/// List all users - no parameters, no validation
pub fn index(_request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  user.list(db) |> response.many_rows(user.encode_list)
}

/// Get single user - extract param, call model, respond
pub fn show(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  user.get(db, id) |> response.one_row(user.encode)
}

/// Create user - validate body, call model, respond
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

/// Delete user - extract param, call model, respond
pub fn delete(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  user.delete(db, id) |> response.success
}
```

## Framework Utilities

### 1. JSON Validators (`dream/validators/json_validator`)

Validates and decodes JSON request bodies.

```gleam
import dream/validators/json_validator.{validate_or_respond}

let decoder = {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

case validate_or_respond(request.body, decoder) {
  Error(response) -> response  // Auto-formatted error response
  Ok(data) -> // Use validated data
}
```

**Functions**:
- `validate`: Returns `Result(decoded, ValidationError)`
- `validate_or_respond`: Returns `Result(decoded, Response)` - convenience wrapper
- `error_response`: Converts `ValidationError` to JSON error response

### 2. Postgres Response Helpers (`dream/services/postgres/response`)

Converts postgres query results to HTTP responses.

```gleam
import dream/services/postgres/response

// Single row - returns 404 if no rows, 500 on DB error
user.get(db, id) |> response.one_row(user.encode)

// Multiple rows - returns empty array if no rows, 500 on DB error
user.list(db) |> response.many_rows(user.encode_list)

// Success/failure - for operations that don't return data
user.delete(db, id) |> response.success
```

**Functions**:
- `one_row`: Extract single row, encode to JSON, return 200/404/500
- `many_rows`: Extract all rows, encode to JSON array, return 200/500
- `success`: Return 200 on success, 500 on error (for DELETE, UPDATE without RETURNING)

### 3. JSON Encoding Utilities (`dream/utilities/json/encoders`)

General-purpose encoders for common Gleam types.

```gleam
import dream/utilities/json/encoders

json.object([
  #("name", json.string(user.name)),
  #("age", encoders.optional_int(user.age)),
  #("bio", encoders.optional_string(user.bio)),
  #("created_at", encoders.timestamp(user.created_at)),
])
```

**Functions**:
- `optional_string`: Encode `Option(String)` to JSON (null if None)
- `optional_int`: Encode `Option(Int)` to JSON (null if None)
- `optional_float`: Encode `Option(Float)` to JSON (null if None)
- `optional_bool`: Encode `Option(Bool)` to JSON (null if None)
- `timestamp`: Encode `Option(Timestamp)` to JSON string (null if None)

## Standard CRUD Controller Pattern

### List (Index)

```gleam
pub fn index(_request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  entity.list(db) |> response.many_rows(entity.encode_list)
}
```

### Get (Show)

```gleam
pub fn show(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  entity.get(db, id) |> response.one_row(entity.encode)
}
```

### Create

```gleam
pub fn create(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  
  case validate_or_respond(request.body, entity.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      // Extract validated data, call model
      entity.create(db, ...) |> response.one_row(entity.encode_create)
    }
  }
}
```

### Update

```gleam
pub fn update(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  case validate_or_respond(request.body, entity.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      entity.update(db, id, ...) |> response.one_row(entity.encode_update)
    }
  }
}
```

### Delete

```gleam
pub fn delete(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  entity.delete(db, id) |> response.success
}
```

## Model Pattern Details

### Query Functions

Models wrap Squirrel-generated SQL functions, providing a clean API.

```gleam
// Simple pass-through wrapper
pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

// Wrapper with parameter mapping
pub fn get(db: pog.Connection, id: Int) -> Result(pog.Returned(sql.GetUserRow), pog.QueryError) {
  sql.get_user(db, id)
}
```

**Benefits**:
- Consistent API across all models
- Easy to add caching, logging, or other cross-cutting concerns
- Database queries isolated from HTTP concerns

### Decoders

Models provide decoders for request validation.

```gleam
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}
```

**Rules**:
- One decoder per unique request shape
- Reuse decoders when create/update have same fields
- Return tuples for simple cases, custom types for complex data

### JSON Encoders

Models provide multiple encoders for different row types.

```gleam
pub fn encode(user: sql.GetUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_list(user: sql.ListUsersRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_create(user: sql.CreateUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

// Shared helper - DRY principle
fn encode_user_fields(
  id: Int,
  name: String,
  email: String,
  created_at: Option(Timestamp),
) -> json.Json {
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("email", json.string(email)),
    #("created_at", encoders.timestamp(created_at)),
  ])
}
```

**Why multiple encoders?** Gleam's nominal typing requires exact type matches. Even though `GetUserRow`, `ListUsersRow`, etc. have identical fields, they're different types. The shared helper eliminates duplication.

## File Organization

```
src/examples/database/
  controllers/
    users_controller.gleam  # HTTP orchestration
    posts_controller.gleam
  models/
    user.gleam             # User data operations
    post.gleam             # Post data operations
  sql/
    *.sql                  # Raw SQL files
  sql.gleam               # Squirrel-generated query functions
  router.gleam            # Route definitions
  services.gleam          # Service initialization
  main.gleam             # Application entry point
```

## Design Rationale

### Why Separate Controllers and Models?

**Controllers without models** led to:
- Hundreds of lines of error handling boilerplate
- Manual JSON string concatenation
- Duplicated validation logic
- Complex result chains
- Hard to test business logic

**Controllers with models** give us:
- 50%+ reduction in controller code
- Type-safe JSON encoding with `gleam/json`
- Reusable validation and response patterns
- Clear separation of HTTP and data concerns
- Easy to test each layer independently

### Why Not Active Record?

Active Record mixes data and HTTP concerns in the model. Our pattern keeps them separate:
- **Models return Results** (data layer)
- **Controllers return Responses** (HTTP layer)
- **Response helpers bridge the gap** (infrastructure layer)

This maintains clean boundaries and testability.

### Why Framework Utilities?

Patterns like "validate JSON body" and "convert query result to response" are universal across web applications. By providing these in the framework, we:
- Reduce boilerplate across all applications
- Ensure consistent error handling
- Make it easy to evolve the pattern framework-wide
- Stay framework-agnostic (utilities are generic)

## Examples

See the complete examples in:
- `src/examples/database/controllers/users_controller.gleam`
- `src/examples/database/controllers/posts_controller.gleam`
- `src/examples/database/models/user.gleam`
- `src/examples/database/models/post.gleam`

These demonstrate the full CRUD pattern with:
- JSON validation
- Database queries
- Type-safe encoding
- Clean error handling
- Minimal boilerplate

