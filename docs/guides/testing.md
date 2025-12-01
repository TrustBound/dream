# Guide: Testing

**How to test your Dream application.**

Dream uses [dream_test](https://hexdocs.pm/dream_test/), a testing framework
designed for clarity and maintainability. Tests live in `test/`, mirror your
`src/` structure, and use a BDD-style `describe`/`it` pattern.

## Quick Start

```gleam
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{equal, or_fail_with, should}

pub fn tests() {
  describe("users", [
    it("creates user with valid data", fn() {
      create_user("Alice", "alice@example.com")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create user")
    }),
  ])
}
```

Run tests:

```bash
gleam test
```

## Test Structure

### Directory Layout

Tests mirror your source structure:

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
  your_app_test.gleam  # Entry point
```

### Entry Point

Create `test/your_app_test.gleam`:

```gleam
import dream_test/runner.{run_all}
import dream_test/unit.{to_test_cases}
import dream_test/reporter/bdd.{report}
import gleam/io
import gleam/list

import your_app/controllers/users_controller_test
import your_app/models/user_test

pub fn main() {
  [
    to_test_cases("controllers/users", users_controller_test.tests()),
    to_test_cases("models/user", user_test.tests()),
  ]
  |> list.flatten
  |> run_all()
  |> report(io.print)
}
```

### Test Module Pattern

Each test module exports a `tests()` function:

```gleam
import dream_test/unit.{type UnitTest, describe, it}
import dream_test/assertions/should.{equal, be_ok, or_fail_with, should}

pub fn tests() -> UnitTest {
  describe("module_name", [
    describe("function_name", [
      it("does X when Y", fn() {
        // Arrange
        let input = "test"

        // Act
        let result = function_name(input)

        // Assert
        result
        |> should()
        |> equal("expected")
        |> or_fail_with("Should return expected value")
      }),
    ]),
  ])
}
```

## Assertions

### Basic Matchers

```gleam
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_none, be_ok, be_some, be_true,
  contain, contain_string, equal, or_fail_with, should,
}

// Equality
result |> should() |> equal(expected) |> or_fail_with("msg")

// Boolean
condition |> should() |> be_true() |> or_fail_with("msg")
condition |> should() |> be_false() |> or_fail_with("msg")

// Options
option |> should() |> be_some() |> or_fail_with("msg")
option |> should() |> be_none() |> or_fail_with("msg")

// Results
result |> should() |> be_ok() |> or_fail_with("msg")
result |> should() |> be_error() |> or_fail_with("msg")

// Collections
list |> should() |> contain(item) |> or_fail_with("msg")
list |> should() |> be_empty() |> or_fail_with("msg")

// Strings
string |> should() |> contain_string("substring") |> or_fail_with("msg")
```

### Chaining Matchers

Matchers can be chained to extract and assert:

```gleam
// Extract from Option then assert
find_user(1)
|> should()
|> be_some()       // Unwraps Option, passes inner value
|> equal(user)     // Asserts on the unwrapped value
|> or_fail_with("User should exist")

// Extract from Result then assert
validate_email("test@example.com")
|> should()
|> be_ok()         // Unwraps Result, passes Ok value
|> equal(true)     // Asserts on the unwrapped value
|> or_fail_with("Email should be valid")
```

### Custom Matchers

Create domain-specific matchers for cleaner tests:

```gleam
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract user name from validation result
pub fn extract_user_name(
  result: MatchResult(Result(User, ValidationError)),
  getter: fn(User) -> String,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Ok(user)) -> MatchOk(getter(user))
    MatchOk(Error(_)) -> validation_failed_failure()
  }
}

fn validation_failed_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_user_name",
    message: "Expected Ok but got validation error",
    payload: Some(CustomMatcherFailure(
      actual: "Error(...)",
      description: "Validation failed",
    )),
  ))
}
```

Usage:

```gleam
validate_user(json_body)
|> should()
|> extract_user_name(fn(u) { u.name })
|> equal("Alice")
|> or_fail_with("Name should be Alice")
```

**Matcher Guidelines:**

- One matcher per file in `test/matchers/`
- First parameter is always `MatchResult(a)`
- Additional parameters come after (works with pipes)
- No nested `case` statements—extract to helper functions
- Return `MatchResult(b)` for chaining

## Fixtures

Create reusable test data in `test/fixtures/`:

```gleam
// test/fixtures/request.gleam
import dream/http/request.{type Request, Request, Get, Http, Http1}
import gleam/option

pub fn create_request(method: Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn create_request_with_body(method: Method, path: String, body: String) -> Request {
  Request(..create_request(method, path), body: body)
}
```

Usage:

```gleam
import fixtures/request

it("handles POST with body", fn() {
  let req = request.create_request_with_body(Post, "/users", "{\"name\":\"Alice\"}")
  // ...
})
```

## Lifecycle Hooks

### before_each / after_each

Run setup/teardown for each test in a group:

```gleam
import dream_test/unit.{describe, it, before_each, after_each}
import dream_test/types.{AssertionOk}

pub fn tests() {
  describe("database tests", [
    before_each(fn() {
      // Reset test state
      AssertionOk
    }),
    after_each(fn() {
      // Cleanup
      AssertionOk
    }),
    it("creates record", fn() { /* ... */ }),
    it("updates record", fn() { /* ... */ }),
  ])
}
```

### before_all / after_all

Run once before/after all tests in a group (requires `run_suite`):

```gleam
import dream_test/unit.{describe, it, before_all, after_all}
import dream_test/types.{AssertionOk}

pub fn tests() {
  describe("server tests", [
    before_all(fn() {
      // Start server once
      AssertionOk
    }),
    after_all(fn() {
      // Stop server
      AssertionOk
    }),
    it("responds to GET /", fn() { /* ... */ }),
    it("responds to POST /users", fn() { /* ... */ }),
  ])
}
```

## Testing Controllers

Controllers receive `Request`, `Context`, and `Services`:

```gleam
import dream/context
import dream/router.{type EmptyServices, EmptyServices}
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{equal, or_fail_with, should}
import fixtures/request
import your_app/controllers/users_controller

pub fn tests() {
  describe("users_controller", [
    describe("index", [
      it("returns 200 for valid request", fn() {
        let req = request.create_request(Get, "/users")
        let ctx = context.AppContext("test-id")

        users_controller.index(req, ctx, EmptyServices).status
        |> should()
        |> equal(200)
        |> or_fail_with("Should return 200")
      }),
    ]),
  ])
}
```

## Testing Middleware

Test middleware with mock `next` functions:

```gleam
import dream/http/response.{Response, Text}
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{equal, or_fail_with, should}
import fixtures/request
import gleam/option
import your_app/middleware/auth

fn success_handler(_req, _ctx, _svc) {
  Response(200, Text("Success"), [], [], option.None)
}

pub fn tests() {
  describe("auth middleware", [
    it("returns 401 without token", fn() {
      let req = request.create_request(Get, "/protected")
      let ctx = context.AppContext("test-id")

      auth.middleware(req, ctx, EmptyServices, success_handler).status
      |> should()
      |> equal(401)
      |> or_fail_with("Should reject without token")
    }),
    it("calls next with valid token", fn() {
      let req = request.create_request_with_header(Get, "/protected", "Authorization", "Bearer valid")
      let ctx = context.AppContext("test-id")

      auth.middleware(req, ctx, EmptyServices, success_handler).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should pass with valid token")
    }),
  ])
}
```

## Testing Models

Test business logic without HTTP:

```gleam
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{be_error, be_ok, equal, or_fail_with, should}
import your_app/models/user

pub fn tests() {
  describe("user", [
    describe("validate_email", [
      it("accepts valid email", fn() {
        user.validate_email("alice@example.com")
        |> should()
        |> be_ok()
        |> or_fail_with("Should accept valid email")
      }),
      it("rejects empty email", fn() {
        user.validate_email("")
        |> should()
        |> be_error()
        |> or_fail_with("Should reject empty email")
      }),
    ]),
  ])
}
```

## Unit vs Integration Tests

### Unit Tests

- **Location:** `test/your_app/`
- **Requirements:**
  - No external dependencies (database, network, files)
  - Fast (milliseconds)
  - Deterministic
  - Isolated

### Integration Tests

- **Location:** `test/integration/`
- **Requirements:**
  - Can use real services
  - Should clean up after themselves
  - May be slower

```gleam
// test/integration/database_test.gleam
import dream_test/unit.{describe, it, before_each}
import dream_test/types.{AssertionOk}

pub fn tests() {
  describe("database integration", [
    before_each(fn() {
      // Truncate tables
      cleanup_database()
      AssertionOk
    }),
    it("persists user to database", fn() {
      // Uses real database connection
      // ...
    }),
  ])
}
```

## Test Philosophy

### Black Box Testing

Test public interfaces, not implementation details:

```gleam
// ✅ Good - tests observable behavior
it("returns user by ID", fn() {
  find_user(1)
  |> should()
  |> be_some()
  |> or_fail_with("Should find user")
})

// ❌ Bad - tests internal implementation
it("calls database with correct SQL", fn() {
  // Don't test how it works, test what it does
})
```

### One Assertion Per Test

Each test should verify one thing:

```gleam
// ✅ Good - focused tests
describe("create_user", [
  it("returns created user", fn() {
    create_user("Alice", "alice@example.com")
    |> should()
    |> be_ok()
    |> or_fail_with("Should create user")
  }),
  it("sets correct name", fn() {
    create_user("Alice", "alice@example.com")
    |> should()
    |> be_ok()
    |> extract_name()
    |> equal("Alice")
    |> or_fail_with("Name should be Alice")
  }),
])

// ❌ Bad - multiple assertions
it("creates user correctly", fn() {
  let result = create_user("Alice", "alice@example.com")
  result |> should() |> be_ok() |> or_fail_with("...")
  // And then another assertion...
})
```

### Arrange, Act, Assert

Every test follows AAA with blank lines between sections:

```gleam
it("uppercases string", fn() {
  // Arrange
  let input = "hello"

  // Act
  let result = string.uppercase(input)

  // Assert
  result
  |> should()
  |> equal("HELLO")
  |> or_fail_with("Should uppercase")
})
```

## What to Test

### ✅ Do Test

- Public API functions
- Business logic
- Error handling
- Edge cases (empty strings, zero, None)
- Integration points

### ❌ Don't Test

- Private functions directly
- Third-party libraries
- Simple getters/setters
- Configuration objects (unless validation logic)

## Coverage Requirements

All functions in `src/dream/` must have test coverage. If a private function
isn't reachable through public functions, it's dead code—delete it.

## Running Tests

```bash
# Run all tests
gleam test

# Run with make (includes formatting check)
make test
```

## Tips

1. **Write tests first** (TDD) or immediately after
2. **One assertion per test** for clear failures
3. **Test edge cases**: empty, zero, negative, None
4. **Test error paths**: what happens when things fail?
5. **Keep tests fast**: slow tests don't get run
6. **Use fixtures**: don't repeat test data setup

---

**See Also:**

- [dream_test documentation](https://hexdocs.pm/dream_test/)
- [Deployment](deployment.md)
- [REST API](rest-api.md)
