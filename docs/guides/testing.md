# Guide: Testing

**How to test your Dream application.**

Dream uses [dream_test](https://hexdocs.pm/dream_test/), a testing framework
designed for clarity and maintainability. Tests live in `test/`, mirror your
`src/` structure, and use a BDD-style `describe`/`it` pattern.

## Quick Start <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/assertions/should.{be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/testing_guide_user.{create_user}

pub fn tests() -> UnitTest {
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

```text
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

Create `test/your_app_test.gleam`. The last step, `exit_on_failure`, ends the
program with status 1 when a test fails, so `gleam test` and CI fail too:

#### Test entry point <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_entry_point.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/unit.{to_test_cases}
import gleam/io
import gleam/list
import snippets/testing_guide_user_test as user_test
import snippets/testing_guide_users_controller_test as users_controller_test

pub fn main() -> Nil {
  [
    to_test_cases("controllers/users", users_controller_test.tests()),
    to_test_cases("models/user", user_test.tests()),
  ]
  |> list.flatten
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()
}
```

### Test Module Pattern

Each test module exports a `tests()` function:

#### A test module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_test_module.gleam#L1-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/string

pub fn tests() -> UnitTest {
  describe("slug", [
    describe("create_slug", [
      it("joins lowercase words with dashes", fn() {
        // Arrange
        let title = "Hello World"

        // Act
        let result = create_slug(title)

        // Assert
        result
        |> should()
        |> equal("hello-world")
        |> or_fail_with("Should return a lowercase slug")
      }),
    ]),
  ])
}
```

## Assertions

### Basic Matchers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_matchers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{get_query_param}
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_none, be_ok, be_some, be_true, contain,
  contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/int
import gleam/list
import gleam/string

pub fn tests() -> UnitTest {
  describe("basic matchers", [
    // Equality
    it("equal", fn() {
      string.length("Alice")
      |> should()
      |> equal(5)
      |> or_fail_with("Should have 5 letters")
    }),
    // Boolean
    it("be_true", fn() {
      string.is_empty("")
      |> should()
      |> be_true()
      |> or_fail_with("Should be empty")
    }),
    it("be_false", fn() {
      list.is_empty([1])
      |> should()
      |> be_false()
      |> or_fail_with("Should not be empty")
    }),
    // Options
    it("be_some", fn() {
      get_query_param("page=2", "page")
      |> should()
      |> be_some()
      |> or_fail_with("Should find page")
    }),
    it("be_none", fn() {
      get_query_param("page=2", "sort")
      |> should()
      |> be_none()
      |> or_fail_with("Should not find sort")
    }),
    // Results
    it("be_ok", fn() {
      int.parse("42")
      |> should()
      |> be_ok()
      |> or_fail_with("Should parse 42")
    }),
    it("be_error", fn() {
      int.parse("forty-two")
      |> should()
      |> be_error()
      |> or_fail_with("Should not parse words")
    }),
    // Collections
    it("contain", fn() {
      [1, 2, 3]
      |> should()
      |> contain(2)
      |> or_fail_with("Should contain 2")
    }),
    it("be_empty", fn() {
      list.filter([1, 2, 3], fn(number) { number > 5 })
      |> should()
      |> be_empty()
      |> or_fail_with("Should find no numbers above 5")
    }),
    // Strings
    it("contain_string", fn() {
      string.uppercase("hello world")
      |> should()
      |> contain_string("WORLD")
      |> or_fail_with("Should contain WORLD")
    }),
  ])
}
```

### Chaining Matchers

Matchers can be chained to extract and assert:

#### Chaining be_some and be_ok <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L14-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn chaining_tests() -> UnitTest {
  describe("chaining matchers", [
    it("finds user 1", fn() {
      let user = User(id: 1, name: "Alice", email: "alice@example.com")

      // Extract from Option then assert
      find_user(1)
      |> should()
      // Unwraps Option, passes inner value
      |> be_some()
      // Asserts on the unwrapped value
      |> equal(user)
      |> or_fail_with("User should exist")
    }),
    it("accepts a valid email", fn() {
      // Extract from Result then assert
      validate_email("test@example.com")
      |> should()
      // Unwraps Result, passes Ok value
      |> be_ok()
      // Asserts on the unwrapped value
      |> equal("test@example.com")
      |> or_fail_with("Email should be valid")
    }),
  ])
}
```

### Custom Matchers

Create domain-specific matchers for cleaner tests:

#### A custom matcher <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_extract_user_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/validation.{type ValidationError}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}
import snippets/testing_guide_user.{type User}

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

#### Using the custom matcher <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L41-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn custom_matcher_tests() -> UnitTest {
  it("reads the name from a valid user", fn() {
    let json_body =
      "{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}"

    validate_user(json_body)
    |> should()
    |> extract_user_name(fn(user) { user.name })
    |> equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}
```

**Matcher Guidelines:**

- One matcher per file in `test/matchers/`
- First parameter is always `MatchResult(a)`
- Additional parameters come after (works with pipes)
- No nested `case` statements—extract to helper functions
- Return `MatchResult(b)` for chaining

## Fixtures

Create reusable test data in `test/fixtures/`:

#### A request fixture <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_request_fixture.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Method, type Request, Http, Http1, Request, Text}
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
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn create_request_with_body(
  method: Method,
  path: String,
  body: String,
) -> Request {
  Request(..create_request(method, path), body: Text(body))
}
```

#### Using the request fixture <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_fixture_usage.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{Post, Text}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, it}
import fixtures/request as test_request

pub fn tests() -> UnitTest {
  it("creates POST request with body", fn() {
    let request =
      test_request.create_request_with_body(
        Post,
        "/users",
        "{\"name\":\"Alice\"}",
      )

    request.body
    |> should()
    |> equal(Text("{\"name\":\"Alice\"}"))
    |> or_fail_with("Body should be the JSON")
  })
}
```

## Lifecycle Hooks

### before_each / after_each

Run setup/teardown for each test in a group:

#### Setup and teardown for each test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_before_each.gleam#L1-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}
import gleam/string

pub fn tests() -> UnitTest {
  describe("record tests", [
    before_each(fn() {
      // Reset test state
      AssertionOk
    }),
    after_each(fn() {
      // Cleanup
      AssertionOk
    }),
    it("creates record", fn() {
      create_record("Alice")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create record")
    }),
    it("updates record", fn() {
      update_record("Alice", "Alicia")
      |> should()
      |> equal(Ok("Alicia"))
      |> or_fail_with("Should update record")
    }),
  ])
}
```

### before_all / after_all

Run once before/after all tests in a group. Convert the tests with
`to_test_suite` and run them with `run_suite`, because `to_test_cases` and
`run_all` do not run these hooks:

#### Setup and teardown once for a group <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_before_all.gleam#L1-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/dream
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status.{ok}
import dream/router.{route, router}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_all, before_all, describe, it}
import fixtures/request as test_request

pub fn tests() -> UnitTest {
  describe("server tests", [
    before_all(fn() {
      // Start shared resources once, such as a server
      AssertionOk
    }),
    after_all(fn() {
      // Stop them
      AssertionOk
    }),
    it("responds to GET /", fn() {
      let request = test_request.create_request(Get, "/")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should return 200")
    }),
    it("responds to GET /users", fn() {
      let request = test_request.create_request(Get, "/users")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should return 200")
    }),
  ])
}
```

## Testing Controllers

Controllers receive `Request`, `Context`, and `Services`:

#### A controller test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_users_controller_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{AppContext}
import dream/http/request.{Get}
import dream/router.{EmptyServices}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import snippets/testing_guide_users_controller as users_controller

pub fn tests() -> UnitTest {
  describe("users_controller", [
    describe("index", [
      it("returns 200 for valid request", fn() {
        let request = test_request.create_request(Get, "/users")
        let context = AppContext("test-id")

        users_controller.index(request, context, EmptyServices).status
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

#### A middleware test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_auth_middleware_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{AppContext}
import dream/http/header.{Header}
import dream/http/request.{Get, Request}
import dream/http/response.{Response, Text}
import dream/router.{EmptyServices}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/option
import snippets/testing_guide_auth_middleware as auth

fn success_handler(_request, _context, _services) {
  Response(200, Text("Success"), [], [], option.None)
}

pub fn tests() -> UnitTest {
  describe("auth middleware", [
    it("returns 401 without token", fn() {
      let request = test_request.create_request(Get, "/protected")
      let context = AppContext("test-id")

      auth.middleware(request, context, EmptyServices, success_handler).status
      |> should()
      |> equal(401)
      |> or_fail_with("Should reject without token")
    }),
    it("calls next with valid token", fn() {
      let request =
        Request(..test_request.create_request(Get, "/protected"), headers: [
          Header("Authorization", "Bearer valid"),
        ])
      let context = AppContext("test-id")

      auth.middleware(request, context, EmptyServices, success_handler).status
      |> should()
      |> equal(200)
      |> or_fail_with("Should pass with valid token")
    }),
  ])
}
```

## Testing Models

Test business logic without HTTP:

#### A model test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_user_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/assertions/should.{be_error, be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/testing_guide_user as user

pub fn tests() -> UnitTest {
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

#### An integration test that uses the file system <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_integration.gleam#L1-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, before_each, describe, it}
import gleam/result
import simplifile

const test_directory = "tmp/testing_guide_integration"

pub fn tests() -> UnitTest {
  describe("file storage integration", [
    before_each(fn() {
      // Delete files from earlier runs
      case simplifile.delete_all([test_directory]) {
        Ok(_) -> AssertionOk
        Error(_) -> fail_with("Could not delete test files")
      }
    }),
    it("saves user to disk", fn() {
      // Uses the real file system
      save_user(test_directory, "alice", "Alice")
      |> should()
      |> equal(Ok("Alice"))
      |> or_fail_with("Should read back the saved user")
    }),
  ])
}
```

## Test Philosophy

### Black Box Testing

Test public interfaces, not implementation details:

#### Good and bad black box tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L54-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn black_box_tests() -> UnitTest {
  describe("find_user", [
    // ✅ Good - tests observable behavior
    it("returns user by ID", fn() {
      find_user(1)
      |> should()
      |> be_some()
      |> or_fail_with("Should find user")
    }),
    // ❌ Bad - tests internal implementation
    it("stores Alice first in the user list", fn() {
      list_users()
      |> list.first()
      |> should()
      |> be_ok()
      |> extract_name()
      |> equal("Alice")
      |> or_fail_with("Alice should be first")
    }),
  ])
}
```

The bad test checks the order of the stored user list. That order is an
internal detail: the test breaks when the storage changes, even when
`find_user` still returns the right user.


### One Assertion Per Test

Each test should verify one thing:

#### Focused tests and a test with two assertions <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L76-L109"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn one_assertion_tests() -> UnitTest {
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
}

pub fn multiple_assertions_test() -> UnitTest {
  // ❌ Bad - multiple assertions
  it("creates user correctly", fn() {
    let result = create_user("Alice", "alice@example.com")
    let _ = result |> should() |> be_ok() |> or_fail_with("Should create user")
    // And then another assertion...
    result
    |> should()
    |> be_ok()
    |> extract_name()
    |> equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}
```

In the bad test, `let _ =` throws away the result of the first assertion.
dream_test never sees it, so that check can fail and the test still passes.


### Arrange, Act, Assert

Every test follows AAA with blank lines between sections:

#### An Arrange, Act, Assert test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L111-L125"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn arrange_act_assert_test() -> UnitTest {
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
}
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
