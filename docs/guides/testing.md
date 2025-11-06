# Guide: Testing

**How to test your Dream application without losing your sanity.**

We use [Gleeunit](https://hexdocs.pm/gleeunit/), Gleam's standard testing framework. Tests live in `test/`, mirror your `src/` structure, and follow a simple pattern: Arrange, Act, Assert.

## Test Philosophy

Dream follows **black box testing**: test public interfaces only. Don't test private functions. Don't test implementation details. Test behavior.

**Why?** Because tests should survive refactoring. If you change how something works internally but the public API stays the same, your tests should still pass.

## Setup

Tests go in `test/`, not alongside code:

```
src/
  your_app/
    controllers/
      users_controller.gleam
    models/
      user.gleam

test/
  your_app/
    controllers/
      users_controller_test.gleam
    models/
      user_test.gleam
  your_app_test.gleam  # Test entry point
```

Create test entry point `test/your_app_test.gleam`:

```gleam
import gleeunit

pub fn main() {
  gleeunit.main()
}
```

Run tests:

```bash
gleam test
```

## Unit Test Requirements

All unit tests must be:
- **Isolated** - No external dependencies (databases, network, files)
- **Fast** - Milliseconds, not seconds
- **Deterministic** - Same result every time
- **Reliable** - Pass regardless of environment

If your test needs a database, it's not a unit test—it's an integration test.

## Test Naming Convention

```gleam
<function_name>_<condition>_<expected_result>_test()
```

Good names:

```gleam
pub fn create_user_with_valid_data_returns_user_test()
pub fn create_user_with_empty_name_returns_error_test()
pub fn get_user_that_does_not_exist_returns_not_found_test()
```

Bad names:

```gleam
pub fn test_create_user()  // Vague
pub fn user_test()         // Too generic
pub fn test1()             // Meaningless
```

## Testing Controllers

Controllers receive `Request`, `Context`, and `Services`. Mock the services:

```gleam
import dream/core/http/transaction.{Request, Response}
import gleam/dynamic/decode
import gleeunit/should
import your_app/controllers/users_controller
import your_app/test_helpers.{mock_database_service, test_context, test_request}

pub fn index_returns_list_of_users_test() {
  // Arrange
  let request = test_request()
  let context = test_context()
  let services = mock_database_service()
  
  // Act
  let response = users_controller.index(request, context, services)
  
  // Assert
  response.status |> should.equal(200)
  response.body |> should.contain("[")
}
```

Create test helpers in `test/your_app/test_helpers.gleam`:

```gleam
import dream/services/service.{type DatabaseService, DatabaseService}
import your_app/context.{type AppContext, AppContext}
import your_app/services.{type Services, Services}

pub fn test_context() -> AppContext {
  AppContext(request_id: "test-request-id")
}

pub fn test_request() -> Request {
  Request(
    method: Get,
    path: "/test",
    headers: [],
    body: "",
    params: dict.new(),
  )
}

pub fn mock_database_service() -> Services {
  let mock_db = DatabaseService(connection: mock_connection())
  Services(database: mock_db)
}
```

## Testing Models

Models return `Result` types. Test them without HTTP:

```gleam
import gleeunit/should
import your_app/models/user
import your_app/test_helpers.{mock_database}

pub fn create_user_with_valid_data_returns_user_test() {
  // Arrange
  let db = mock_database()
  let name = "Alice"
  let email = "alice@example.com"
  
  // Act
  let result = user.create(db, name, email)
  
  // Assert
  case result {
    Ok(returned) -> {
      case returned.rows {
        [user_row] -> {
          user_row.name |> should.equal(name)
          user_row.email |> should.equal(email)
        }
        _ -> should.fail("Expected one user row")
      }
    }
    Error(_) -> should.fail("Expected Ok, got Error")
  }
}
```

## Testing Middleware

Test middleware with mock `next` functions:

```gleam
import gleeunit/should
import your_app/middleware/auth_middleware

pub fn auth_middleware_without_token_returns_401_test() {
  // Arrange
  let request = test_request()
  let context = test_context()
  let services = test_services()
  let next = fn(_req, _ctx, _svc) {
    panic as "Should not call next"
  }
  
  // Act
  let response = auth_middleware.auth_middleware(request, context, services, next)
  
  // Assert
  response.status |> should.equal(401)
}

pub fn auth_middleware_with_valid_token_calls_next_test() {
  // Arrange
  let request = test_request_with_header("Authorization", "Bearer valid-token")
  let context = test_context()
  let services = test_services()
  let mut next_called = False
  let next = fn(req, ctx, svc) {
    next_called = True
    text_response(ok_status(), "Success")
  }
  
  // Act
  let response = auth_middleware.auth_middleware(request, context, services, next)
  
  // Assert
  next_called |> should.equal(True)
  response.status |> should.equal(200)
}
```

## Mocking Dependencies

Use dependency injection to make things mockable:

```gleam
// Instead of this:
pub fn get_user(id: Int) -> Result(User, Error) {
  let db = get_global_database()  // Hard to test
  query_user(db, id)
}

// Do this:
pub fn get_user(db: Database, id: Int) -> Result(User, Error) {
  query_user(db, id)  // Easy to mock the database
}
```

Create mock implementations:

```gleam
pub fn mock_database() -> Database {
  Database {
    query: fn(sql, params) {
      // Return test data
      Ok([test_user()])
    },
    execute: fn(sql, params) {
      Ok(1)
    },
  }
}
```

## Integration Tests

Integration tests touch real external systems. Keep them separate:

```
test/
  integration/
    database_test.gleam
    api_test.gleam
```

These tests:
- ✅ Can be slower
- ✅ Can depend on external services
- ✅ Should clean up after themselves

```gleam
import gleeunit/should
import your_app/database

pub fn database_connection_works_test() {
  // Arrange
  let assert Ok(db) = database.init_test_database()
  
  // Act
  let result = user.create(db, "Test User", "test@example.com")
  
  // Assert
  result |> should.be_ok()
  
  // Cleanup
  database.cleanup(db)
}
```

Run integration tests separately:

```bash
gleam test --only integration
```

## Coverage Requirements

All functions in `src/dream/` must have 100% test coverage. If a private function isn't reachable through public functions, it's dead code—delete it.

No coverage tools? Just review:
- Every public function has tests
- Every code path is exercised
- Edge cases are covered

## Arrange, Act, Assert Pattern

Every test follows AAA:

```gleam
pub fn example_test() {
  // Arrange: Set up test data
  let input = "test value"
  let expected = "TEST VALUE"
  
  // Act: Execute the function
  let result = string.uppercase(input)
  
  // Assert: Verify the outcome
  result |> should.equal(expected)
}
```

Add blank lines between sections. Makes tests readable.

## Common Assertions

```gleam
import gleeunit/should

// Equality
result |> should.equal(expected)
result |> should.not_equal(unexpected)

// Boolean
condition |> should.be_true()
condition |> should.be_false()

// Options
option |> should.be_some()
option |> should.be_none()

// Results
result |> should.be_ok()
result |> should.be_error()

// Lists
list |> should.contain(item)
```

## Testing JSON Encoding/Decoding

```gleam
import gleam/json
import gleeunit/should

pub fn user_encoder_creates_valid_json_test() {
  // Arrange
  let user = User(id: 1, name: "Alice", email: "alice@example.com")
  
  // Act
  let json_string = user.encode(user) |> json.to_string
  
  // Assert
  json_string |> should.contain("\"name\":\"Alice\"")
  json_string |> should.contain("\"email\":\"alice@example.com\"")
}

pub fn user_decoder_parses_valid_json_test() {
  // Arrange
  let json_string = "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
  
  // Act
  let result = json.decode(json_string, user.decoder())
  
  // Assert
  case result {
    Ok(#(name, email)) -> {
      name |> should.equal("Alice")
      email |> should.equal("alice@example.com")
    }
    Error(_) -> should.fail("Expected Ok, got Error")
  }
}
```

## What NOT to Test

Don't test:
- ❌ Private functions directly
- ❌ Third-party libraries (they have their own tests)
- ❌ Getters/setters with no logic
- ❌ Configuration objects (unless validation logic)

Do test:
- ✅ Public API functions
- ✅ Business logic
- ✅ Error handling
- ✅ Edge cases
- ✅ Integration points

## Running Tests

```bash
# Run all tests
gleam test

# Run tests for a specific module
gleam test --module your_app/controllers/users_controller_test

# Watch mode (run tests on file changes)
gleam test --watch
```

## Tips

1. **Write tests first** (TDD) or right after (TAD). Don't leave it for later.
2. **One assertion per test** when possible. Makes failures clear.
3. **Test edge cases**: empty strings, zero, negative numbers, None values
4. **Test error paths**: What happens when things go wrong?
5. **Keep tests fast**: If tests are slow, you won't run them
6. **Don't mock what you don't own**: Use real types when possible

## Example: Complete Test File

```gleam
import gleeunit
import gleeunit/should
import your_app/models/user
import your_app/test_helpers.{mock_database}

pub fn main() {
  gleeunit.main()
}

pub fn create_user_with_valid_data_returns_user_test() {
  let db = mock_database()
  let result = user.create(db, "Alice", "alice@example.com")
  
  case result {
    Ok(returned) -> {
      case returned.rows {
        [user_row] -> {
          user_row.name |> should.equal("Alice")
          user_row.email |> should.equal("alice@example.com")
        }
        _ -> should.fail("Expected one row")
      }
    }
    Error(_) -> should.fail("Expected Ok")
  }
}

pub fn create_user_with_empty_name_returns_error_test() {
  let db = mock_database()
  let result = user.create(db, "", "alice@example.com")
  
  result |> should.be_error()
}

pub fn get_user_that_exists_returns_user_test() {
  let db = mock_database()
  let result = user.get(db, 1)
  
  result |> should.be_ok()
}

pub fn get_user_that_does_not_exist_returns_error_test() {
  let db = mock_database()
  let result = user.get(db, 999)
  
  result |> should.be_error()
}
```

## Summary

Testing in Dream:
- ✅ Black box testing (public interfaces only)
- ✅ Tests in `test/` directory
- ✅ Mock dependencies via dependency injection
- ✅ Follow AAA pattern
- ✅ Unit tests: fast, isolated, deterministic
- ✅ Integration tests: separate directory
- ✅ 100% coverage of `src/dream/`

Good tests make refactoring safe. Write them.

---

**[← Back: Middleware](middleware.md)** | **[Up: Documentation](../../README.md)** | **[Next: Deployment →](deployment.md)**

