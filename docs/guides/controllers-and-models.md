# Guide: Controllers and Models

**The three-layer architecture that keeps controllers from becoming thousand-line nightmares.**

If you've worked on a web project that's more than a few months old, you've seen it: controllers that do everything. Database queries mixed with HTTP logic mixed with business rules mixed with JSON serialization. 500 lines per function. Good luck testing that.

Dream uses a **three-layer architecture** that keeps each layer focused:

1. **Controllers** - HTTP orchestration only
2. **Models** - Data operations only
3. **Utilities** - Reusable framework helpers

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

Here's the same operation with the three-layer pattern:

```gleam
import dream/core/http/transaction.{type Request, type Response}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import examples/database/models/user
import examples/database/services.{type Services}

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

**8 lines instead of 40.** And it's actually readable.

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
import dream/services/postgres/response
import examples/database/models/user
import examples/database/services.{type Services}

pub fn index(_request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  user.list(db) |> response.many_rows(user.encode_list)
}
```

#### Get (Show)

```gleam
import dream/core/http/transaction.{get_param}
import gleam/int
import gleam/result

pub fn show(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  user.get(db, id) |> response.one_row(user.encode)
}
```

#### Create

```gleam
import dream/validators/json_validator.{validate_or_respond}

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

#### Update

```gleam
pub fn update(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.update(db, id, name, email) |> response.one_row(user.encode_update)
    }
  }
}
```

#### Delete

```gleam
pub fn delete(request: Request, _context: Context, services: Services) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)
  
  user.delete(db, id) |> response.success
}
```

That's it. Every CRUD controller looks like this. Consistent. Predictable. Easy to test.

## Layer 2: Models

**Responsibility:** Data operations only.

Models handle:
- Wrapping database queries (Squirrel-generated SQL)
- Providing JSON decoders for request validation
- Providing JSON encoders for responses
- Returning `Result` types (never `Response` types)

### Complete Model Example

```gleam
import dream/utilities/json/encoders
import examples/database/sql
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp
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

// JSON encoders for different row types
pub fn encode(user: sql.GetUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_list(user: sql.ListUsersRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_create(user: sql.CreateUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_update(user: sql.UpdateUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

// Shared encoder implementation (DRY principle)
fn encode_user_fields(
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

### Why Multiple Encoders?

Squirrel generates different types for each SQL query: `GetUserRow`, `ListUsersRow`, `CreateUserRow`, etc. Even though they have the same fields, they're **different types** (nominal typing).

You can't use one encoder for all. But you can share the implementation:

```gleam
// Public encoders for each type
pub fn encode(user: sql.GetUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

pub fn encode_list(user: sql.ListUsersRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

// Private shared implementation
fn encode_user_fields(id, name, email, created_at) -> json.Json {
  json.object([...])
}
```

DRY principle respected. Type safety maintained.

### Why Wrap Squirrel Functions?

You could call Squirrel-generated functions directly from controllers:

```gleam
sql.list_users(db) |> response.many_rows(user.encode_list)
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

## Layer 3: Utilities

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

### PostgreSQL Response Helpers (`dream/services/postgres/response`)

Converts database `Result` types to HTTP `Response` types:

```gleam
import dream/services/postgres/response

// Single row - returns 404 if no rows, 500 on DB error
user.get(db, id) |> response.one_row(user.encode)

// Multiple rows - returns empty array if no rows, 500 on DB error
user.list(db) |> response.many_rows(user.encode_list)

// Success/failure - for operations that don't return data
user.delete(db, id) |> response.success
```

These handle all the tedious error cases you'd otherwise write manually in every controller.

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
    user.gleam                # User data operations
    post.gleam                # Post data operations
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
- ✅ Error handling centralized
- ✅ JSON encoding in one place (models)
- ✅ Easy to test (each layer independent)
- ✅ Clean separation of concerns

**Result:** 50%+ reduction in controller code. Controllers become readable.

## Design Rationale

### Why Not Active Record?

Active Record mixes data and HTTP concerns in the model:

```gleam
// Active Record style (we don't do this)
user.to_json()    // Model knows about JSON
user.to_response()  // Model knows about HTTP
```

Our pattern keeps them separate:

```gleam
// Dream pattern
user.create(db, name, email)  // Returns Result (data layer)
user.encode(user_row)          // Returns Json (serialization)
response.one_row(result, encoder)  // Returns Response (HTTP layer)
```

Each layer has one responsibility. Easy to test. Easy to change.

### Why Framework Utilities?

Patterns like "validate JSON" and "convert query result to response" are universal. By providing them in the framework:
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

The three-layer architecture is simple:

1. **Controllers** handle HTTP and call models
2. **Models** handle data and return Results
3. **Utilities** provide reusable helpers

This keeps controllers small, models focused, and code testable.

**Want to see it in action?**

Check out `src/examples/database/` for a complete implementation with:
- Full CRUD operations
- JSON validation
- Database queries
- Type-safe encoding
- Clean separation

---

**[← Back: Documentation](../../README.md)** | **[Next: Middleware Guide →](middleware.md)**

