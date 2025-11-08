# Guide: Controllers, Models, and Views

**The four-layer architecture that keeps controllers from becoming thousand-line nightmares.**

If you've worked on a web project that's more than a few months old, you've seen it: controllers that do everything. Database queries mixed with HTTP logic mixed with business rules mixed with JSON serialization. 500 lines per function. Good luck testing that.

Dream uses a **four-layer architecture** that keeps each layer focused:

1. **Controllers** - HTTP orchestration only
2. **Models** - Data operations only
3. **Views** - Presentation only
4. **Utilities** - Reusable framework helpers

This guide explains the pattern and shows you how to use it effectively.

## The Problem

Here's what controllers look like *without* the pattern:

```gleam
pub fn create(request, context, services) {
  let db = services.database.connection
  
  // Parse JSON manually
  case json.decode(request.body) {
    Error(_) -> text_response(bad_request_status(), "Invalid JSON")
    Ok(parsed) -> {
      // Extract fields manually with lots of error handling
      case get_field(parsed, "name") {
        Error(_) -> text_response(bad_request_status(), "Missing name")
        Ok(name) -> {
          case get_field(parsed, "email") {
            Error(_) -> text_response(bad_request_status(), "Missing email")
            Ok(email) -> {
              // Execute SQL query inline
              case sql.create_user(db, name, email) {
                Error(db_error) ->
                  text_response(
                    internal_server_error_status(),
                    "Database error: " <> error_to_string(db_error),
                  )
                Ok(returned) if list.length(returned.rows) > 0 -> {
                  let assert [user_row] = returned.rows
                  // Manually build JSON response
                  let json_body =
                    "{"
                    <> "\"id\": " <> int.to_string(user_row.id) <> ","
                    <> "\"name\": \"" <> user_row.name <> "\","
                    <> "\"email\": \"" <> user_row.email <> "\""
                    <> "}"
                  json_response(ok_status(), json_body)
                }
                Ok(_) ->
                  text_response(
                    internal_server_error_status(),
                    "No user returned",
                  )
              }
            }
          }
        }
      }
    }
  }
}
```

That's 40+ lines of nested error handling for a simple CREATE operation. And we've all written code like this.

## The Solution

Here's the same operation with the four-layer pattern:

```gleam
import dream/core/http/transaction.{type Request, type Response}
import dream/validators/json_validator.{validate_or_respond}
import models/user
import views/user_view
import services.{type Services}

pub fn create(request: Request, _context: Context, services: Services) -> Response {
  // Extract dependencies first
  let db = services.database.connection
  
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email)
      |> user_view.respond_created()
    }
  }
}
```

**7 lines instead of 40.** And it's actually readable.

Let's break down each layer.

## Layer 1: Controllers

**Responsibility:** HTTP orchestration only.

Controllers handle:
- Extracting dependencies from services
- Parsing path parameters
- Validating request bodies
- Calling model functions
- Converting Results to HTTP Responses

Controllers should NOT:
- Execute SQL queries directly
- Encode JSON manually
- Contain business logic
- Handle database errors directly

### Standard Controller Pattern

Every CRUD controller follows this pattern:

#### List (Index)

```gleam
import dream/core/http/transaction.{type Request, type Response}
import models/user
import views/user_view
import services.{type Services}

pub fn index(_request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  user.list(db)
  |> user_view.respond_list()
}
```

#### Get (Show)

```gleam
import dream/core/http/transaction.{get_param}

pub fn show(request: Request, _context: Context, services: Services) -> Response {
  // Extract dependencies and path params first
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let db = services.database.connection

  user.get(db, id)
  |> user_view.respond()
}
```

#### Create

```gleam
import dream/validators/json_validator.{validate_or_respond}

pub fn create(request: Request, _context: Context, services: Services) -> Response {
  // Extract dependencies first
  let db = services.database.connection
  
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email)
      |> user_view.respond_created()
    }
  }
}
```

#### Update

```gleam
pub fn update(request: Request, _context: Context, services: Services) -> Response {
  // Extract dependencies and path params first
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let db = services.database.connection

  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.update(db, id, name, email)
      |> user_view.respond_updated()
    }
  }
}
```

#### Delete

```gleam
pub fn delete(request: Request, _context: Context, services: Services) -> Response {
  // Extract dependencies and path params first
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let db = services.database.connection

  user.delete(db, id)
  |> user_view.respond_deleted()
}
```

That's it. Every CRUD controller looks like this. Consistent. Predictable. Easy to test.

## Layer 2: Models

**Responsibility:** Data operations only.

Models handle:
- Wrapping database queries (Squirrel-generated SQL)
- Providing JSON decoders for request validation (input only)
- Returning `Result` types (never `Response` types)
- Business logic and data transformations

Models do NOT handle:
- JSON encoding for responses (that's presentation → views)
- HTTP responses (that's web layer → controllers/views)
- Error formatting (views decide how errors look)

### Complete Model Example

```gleam
import sql
import gleam/dynamic/decode
import pog

// Query functions - wrap Squirrel SQL, return Results
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

pub fn update(
  db: pog.Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(pog.Returned(sql.UpdateUserRow), pog.QueryError) {
  sql.update_user(db, name, email, id)
}

pub fn delete(db: pog.Connection, id: Int) -> Result(pog.Returned(Nil), pog.QueryError) {
  sql.delete_user(db, id)
}

// Request decoder for JSON validation
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}
```

**That's it.** Database queries and input validation. Nothing else.

### Why Wrap Squirrel Functions?

You could call Squirrel-generated functions directly from controllers:

```gleam
sql.list_users(db) |> user_view.respond_list()
```

But wrapping them in models gives you:
- **Consistent API** across all models
- **Easy to add logging** or caching later
- **Isolated database queries** from HTTP concerns
- **Better testability** (mock the model, not Squirrel)

The wrapper is simple:

```gleam
pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}
```

One line. But it pays off.

## Layer 3: Views

**Responsibility:** Presentation only.

Domain-specific views handle:
- Converting model data to HTTP responses
- JSON/HTML/CSV encoding for their domain (users, posts, products, etc.)
- Success status codes (200, 201, etc.)
- Unwrapping `Result` types from models

Domain views do NOT handle:
- Generic HTTP errors (use shared `views/errors.gleam`)
- Database queries or connections (that's models)
- Request validation (that's controllers + validators)
- Business logic (that's models)

Note: Views do receive database result types (`pog.Returned`) to unwrap them,
but they don't perform queries or manage connections.

### Complete View Example

```gleam
import dream/core/http/statuses.{created_status, not_found_status, ok_status, internal_server_error_status}
import dream/core/http/transaction.{type Response, json_response}
import dream/utilities/json/encoders
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog
import sql

/// Respond with a single user
pub fn respond(
  result: Result(pog.Returned(sql.GetUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_with_rows(rows: List(sql.GetUserRow)) -> Response {
  case rows {
    [user] -> json_response(ok_status(), to_json(user))
    [] -> errors.not_found("User not found")
    _ -> errors.not_found("User not found")
  }
}

/// Respond with a list of users
pub fn respond_list(
  result: Result(pog.Returned(sql.ListUsersRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> json_response(ok_status(), list_to_json(returned.rows))
    Error(_) -> errors.internal_error()
  }
}

/// Respond with a created user (201 status)
pub fn respond_created(
  result: Result(pog.Returned(sql.CreateUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_created_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_created_with_rows(rows: List(sql.CreateUserRow)) -> Response {
  case rows {
    [user] -> json_response(created_status(), to_json_created(user))
    [] -> errors.internal_error()
    _ -> errors.internal_error()
  }
}

// Private helper functions - all encoding logic lives here

fn to_json(user: sql.GetUserRow) -> String {
  encode_user(user.id, user.name, user.email, user.created_at)
  |> json.to_string()
}

fn to_json_created(user: sql.CreateUserRow) -> String {
  encode_user(user.id, user.name, user.email, user.created_at)
  |> json.to_string()
}

fn list_to_json(users: List(sql.ListUsersRow)) -> String {
  users
  |> list.map(fn(user) {
    encode_user(user.id, user.name, user.email, user.created_at)
  })
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

/// Shared JSON encoder for all user row types
fn encode_user(
  id: Int,
  name: String,
  email: String,
  created_at: option.Option(timestamp.Timestamp),
) -> json.Json {
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("email", json.string(email)),
    #("created_at", encoders.timestamp(created_at)),
  ])
}

```

**Key points:**
- Views receive `Result` types from models and unwrap them
- All JSON encoding happens in views (not models)
- Generic HTTP errors use shared `views/errors.gleam`
- Helper functions avoid nested case statements
- Multiple row types (GetUserRow, CreateUserRow, etc.) share the same encoder via a private helper

### Shared Errors View

Generic HTTP errors belong in a shared view, not duplicated in every domain view:

```gleam
// views/errors.gleam

import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, not_found_status,
}
import dream/core/http/transaction.{type Response, json_response}

/// 404 Not Found response
pub fn not_found(message: String) -> Response {
  json_response(not_found_status(), "{\"error\": \"" <> message <> "\"}")
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  json_response(
    internal_server_error_status(),
    "{\"error\": \"Internal server error\"}",
  )
}

/// 400 Bad Request response
pub fn bad_request(message: String) -> Response {
  json_response(bad_request_status(), "{\"error\": \"" <> message <> "\"}")
}
```

Then use it from domain views:

```gleam
// views/user_view.gleam
import views/errors

pub fn respond(result: Result(...)) -> Response {
  case result {
    Ok(returned) -> respond_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_with_rows(rows: List(sql.GetUserRow)) -> Response {
  case rows {
    [user] -> json_response(ok_status(), to_json(user))
    [] -> errors.not_found("User not found")
    _ -> errors.not_found("User not found")
  }
}
```

Domain views focus on formatting their data. Helper functions avoid nested cases. Errors are shared and reusable.

### Why Multiple Row Types?

Squirrel generates different types for each SQL query: `GetUserRow`, `ListUsersRow`, `CreateUserRow`, etc. 
Even though they have the same fields, they're **different types** (nominal typing).

You can't use one encoder for all. But you can share the implementation with a private helper function.

## Layer 4: Utilities

**Responsibility:** Reusable framework helpers.

Dream provides utilities that eliminate boilerplate:

### JSON Validation (`dream/validators/json_validator`)

```gleam
import dream/validators/json_validator.{validate_or_respond}

case validate_or_respond(request.body, user.decoder()) {
  Error(response) -> response  // Auto-formatted error response
  Ok(data) -> // Use validated data
}
```

If validation fails, returns:

```json
{
  "error": "Validation failed",
  "details": ["Field 'name' is required", "Field 'email' must be a string"]
}
```

### Query Result Helpers (`dream/utilities/query`)

Extract data from Pog query results cleanly:

```gleam
import dream/utilities/query

// Extract first row (for single-record queries)
case user.get(db, id) |> query.first_row() {
  Ok(user) -> user_view.respond(user)
  Error(query.NotFound) -> not_found_response()
  Error(query.DatabaseError) -> error_response()
}

// Extract all rows (for list queries)
case user.list(db) |> query.all_rows() {
  Ok(users) -> user_view.respond_list(users)
  Error(query.DatabaseError) -> error_response()
}
```

These helpers convert `Result(pog.Returned(row), pog.QueryError)` to `Result(row, QueryError)`,
extracting the data you actually want and distinguishing between "not found" and "database error".

### JSON Encoding Utilities (`dream/utilities/json/encoders`)

General-purpose encoders for common Gleam types:

```gleam
import dream/utilities/json/encoders

json.object([
  #("name", json.string(user.name)),
  #("age", encoders.optional_int(user.age)),
  #("bio", encoders.optional_string(user.bio)),
  #("verified", encoders.optional_bool(user.verified)),
  #("created_at", encoders.timestamp(user.created_at)),
])
```

No more writing `case option { Some(x) -> json.int(x); None -> json.null() }` everywhere.

## File Organization

```
src/your_app/
  controllers/
    users_controller.gleam    # HTTP orchestration
    posts_controller.gleam
  models/
    user.gleam                # User data operations (queries + input decoders)
    post.gleam                # Post data operations (queries + input decoders)
  views/
    user_view.gleam           # User presentation (JSON encoding)
    post_view.gleam           # Post presentation (JSON encoding)
    errors.gleam              # Shared HTTP error responses
  sql/
    list_users.sql            # Raw SQL files
    get_user.sql
    create_user.sql
    ...
  sql.gleam                   # Squirrel-generated query functions
  router.gleam                # Route definitions
  services.gleam              # Service initialization
  main.gleam                  # Application entry point
```

Clear separation. Each piece has one job.

## Benefits

### Before the Pattern

- ❌ Controllers: 200+ lines of boilerplate
- ❌ Error handling repeated everywhere
- ❌ JSON encoding scattered throughout
- ❌ Hard to test (everything coupled)
- ❌ Business logic mixed with HTTP logic

### After the Pattern

- ✅ Controllers: 5-10 lines each
- ✅ Error handling centralized (shared errors view)
- ✅ JSON encoding in one place (domain views)
- ✅ Easy to test (each layer independent)
- ✅ Clean separation of concerns

**Result:** 50%+ reduction in controller code. Controllers become readable.

## Design Rationale

### Why Not Active Record?

Active Record mixes data and presentation in the model:

```gleam
// Active Record style (we don't do this)
user.to_json()      // Model knows about JSON
user.to_response()  // Model knows about HTTP
user.save()         // Model manages its own persistence
```

Our pattern separates them into distinct layers:

```gleam
// Dream pattern - clean separation
user.create(db, name, email)     // Model: Returns Result (data layer)
user_view.respond_created(result) // View: Unwraps Result, encodes JSON, returns Response

// Models don't query HTTP - just return data
// Views don't query databases - just format results
// Controllers connect both layers
```

Each layer has one job. Models focus on data, views focus on presentation, controllers connect them.

### Why Framework Utilities?

Patterns like "validate JSON" and "extract query results" are universal. By providing them in the framework:
- ✅ Reduces boilerplate across all applications
- ✅ Ensures consistent error handling
- ✅ Makes it easy to evolve the pattern framework-wide
- ✅ Stays framework-agnostic (utilities are generic)

You're not locked in. Use the utilities or don't. Your choice.

## Advanced Patterns

### Complex Validation

For validation beyond simple types:

```gleam
pub fn decoder() -> decode.Decoder(UserData) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(UserData(name:, email:, age:))
  |> decode.then(validate_user_data)
}

fn validate_user_data(data: UserData) -> decode.Decoder(UserData) {
  case data.age < 18 {
    True -> decode.fail("Must be 18 or older")
    False -> decode.success(data)
  }
}
```

### Business Logic in Models

Models can contain business logic related to data:

```gleam
pub fn create_with_defaults(
  db: pog.Connection,
  name: String,
  email: String,
) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError) {
  // Normalize email before saving
  let normalized_email = string.lowercase(email)
  
  // Generate username from name
  let username = generate_username(name)
  
  sql.create_user(db, name, normalized_email, username)
}

fn generate_username(name: String) -> String {
  name
  |> string.lowercase
  |> string.replace(" ", "_")
}
```

Just keep it data-focused. HTTP concerns stay in controllers.

### Model Composition

Models can call other models:

```gleam
pub fn create_with_profile(
  db: pog.Connection,
  user_data: UserData,
  profile_data: ProfileData,
) -> Result(CreatedUser, Error) {
  use user <- result.try(user.create(db, user_data))
  use profile <- result.try(profile.create(db, user.id, profile_data))
  Ok(CreatedUser(user:, profile:))
}
```

### Testing

Each layer tests independently:

**Model tests** (no HTTP):
```gleam
pub fn create_user_with_valid_data_returns_user_test() {
  let mock_db = mock_database()
  let result = user.create(mock_db, "Alice", "alice@example.com")
  
  assert Ok(returned) = result
  assert [user_row] = returned.rows
  user_row.name |> should.equal("Alice")
}
```

**Controller tests** (mock models):
```gleam
pub fn create_endpoint_with_valid_json_returns_201_test() {
  let request = test_request_with_body("{\"name\":\"Alice\",\"email\":\"alice@example.com\"}")
  let services = test_services_with_mock_db()
  
  let response = users_controller.create(request, test_context(), services)
  
  response.status |> should.equal(201)
}
```

Clean. Focused. Fast.

## Summary

The four-layer architecture is simple:

1. **Controllers** handle HTTP orchestration and call models
2. **Models** handle data operations and return Results
3. **Views** handle presentation and return Responses
4. **Utilities** provide reusable helpers

This keeps controllers small, models data-focused, views presentation-focused, and code testable.

**Want to see it in action?**

Check out `examples/database/` for a complete implementation with:
- Full CRUD operations
- JSON validation
- Database queries
- Type-safe encoding
- Clean separation

---

**[← Back: Documentation](../../README.md)** | **[Next: Middleware Guide →](middleware.md)**

