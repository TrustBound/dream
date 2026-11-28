[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Test your controllers and your app

# Test your controllers and your app

You want to change your app without fear: know that each route still answers what it should, that the middleware still refuses what it should, and that a failure tells you exactly what broke. Dream apps are plain functions and records, so most of that needs no server at all. This guide tests a Dream app with [Dream Test](https://hexdocs.pm/dream_test/3.0.0/), the framework that Dream's own tests use: controllers, middleware and models alone, the whole router with `dream.route_request`, and a real server when you need one. The reports shown are the real output of the tests shown.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which kind of test to write](#which-kind-of-test-to-write)
- [Quick Start](#quick-start)
- [Step 1: Set up the test runner](#step-1-set-up-the-test-runner)
- [Step 2: Assert with matchers](#step-2-assert-with-matchers)
- [Step 3: Build requests with fixtures](#step-3-build-requests-with-fixtures)
- [Step 4: Test a controller](#step-4-test-a-controller)
- [Step 5: Test a middleware](#step-5-test-a-middleware)
- [Step 6: Test a model](#step-6-test-a-model)
- [Step 7: Set up and tear down](#step-7-set-up-and-tear-down)
- [Step 8: Test against real services](#step-8-test-against-real-services)
- [Step 9: Test the whole app through its routes](#step-9-test-the-whole-app-through-its-routes)
- [When a test fails](#when-a-test-fails)
- [How to write a good test](#how-to-write-a-good-test)
- [What to Test](#what-to-test)
- [Run the tests](#run-the-tests)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A test entry point that `gleam test` runs, and test modules that mirror `src/`.
- Tests of a controller, a middleware and a model, with requests built by a fixture.
- A test of the whole app through its routes, with no server.
- A test that starts a real server on a port and stops it.
- The report of a passing run and of a failing test.

## Before you start

Add Dream Test as a dev dependency:

```sh
gleam add --dev dream_test
```

[Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) ends with a first test of this kind. Each guide has a "Test your code" section for its own topic.

## Which kind of test to write

| What you check | Test | Needs |
|:---|:---|:---|
| A controller's answer for a request | Call the controller with a request you build | Nothing but the function |
| A middleware refuses or lets through | Call it with a `next` that records what it got | Nothing but the function |
| A controller that takes Dream's `AppContext` | Build the context with `context.new_context("test-id")` | Nothing but the function |
| A route, its middleware and its controller together | `dream.route_request(router, request, context, services)` | Your router and test services |
| Business logic of a model or operation | Call it with test data or test services | Nothing, or a stub in services |
| SQL, files, HTTP clients, the real server | An integration test, or `server.listen_with_handle` | The real service, and clean-up |

## Quick Start

### A first test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/testing_guide_user.{create_user}

pub fn tests() -> TestSuite {
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

Run the tests with `gleam test`.

## Step 1: Set up the test runner

### Directory Layout

Tests live in `test/` and mirror your source structure:

- `src/your_app/controllers/users_controller.gleam` is tested by `test/your_app/controllers/users_controller_test.gleam`.
- `src/your_app/models/user.gleam` is tested by `test/your_app/models/user_test.gleam`.
- `test/your_app_test.gleam` is the entry point that `gleam test` runs.

### Entry Point

Create `test/your_app_test.gleam`. With `exit_on_failure`, `runner.run` ends
the program with status 1 when a test fails, so `gleam test` and CI fail too:

#### Test entry point <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_entry_point.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import snippets/testing_guide_user_test as user_test
import snippets/testing_guide_users_controller_test as users_controller_test

pub fn main() {
  runner.new([users_controller_test.tests(), user_test.tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Test Module Pattern

Each test module exports a `tests()` function:

#### A test module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_test_module.gleam#L1-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/string

pub fn tests() -> TestSuite {
  describe("slug", [
    group("create_slug", [
      it("joins lowercase words with dashes", fn() {
        // Arrange
        let title = "Hello World"

        // Act
        let result = create_slug(title)

        // Assert
        result
        |> should()
        |> be_equal("hello-world")
        |> or_fail_with("Should return a lowercase slug")
      }),
    ]),
  ])
}
```

## Step 2: Assert with matchers

### Basic Matchers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_matchers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{get_query_param}
import dream_test/matchers.{
  be_empty, be_equal, be_error, be_false, be_none, be_ok, be_some, be_true,
  contain, contain_string, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/string

pub fn tests() -> TestSuite {
  describe("basic matchers", [
    // Equality
    it("equal", fn() {
      string.length("Alice")
      |> should()
      |> be_equal(5)
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

#### Chaining be_some and be_ok <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L15-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn chaining_tests() -> TestSuite {
  describe("chaining matchers", [
    it("finds user 1", fn() {
      let user = User(id: 1, name: "Alice", email: "alice@example.com")

      // Extract from Option then assert
      find_user(1)
      |> should()
      // Unwraps Option, passes inner value
      |> be_some()
      // Asserts on the unwrapped value
      |> be_equal(user)
      |> or_fail_with("User should exist")
    }),
    it("accepts a valid email", fn() {
      // Extract from Result then assert
      validate_email("test@example.com")
      |> should()
      // Unwraps Result, passes Ok value
      |> be_ok()
      // Asserts on the unwrapped value
      |> be_equal("test@example.com")
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
  result: MatchResult(Result(User, List(ValidationError))),
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

#### Using the custom matcher <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L42-L53"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn custom_matcher_tests() -> UnitNode {
  it("reads the name from a valid user", fn() {
    let json_body =
      "{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}"

    validate_user(json_body)
    |> should()
    |> extract_user_name(fn(user) { user.name })
    |> be_equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}
```

**Matcher Guidelines:**

- One matcher per file in `test/matchers/`
- First parameter is always `MatchResult(a)`
- Additional parameters come after (works with pipes)
- No nested `case` statements: extract to helper functions
- Return `MatchResult(b)` for chaining

## Step 3: Build requests with fixtures

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
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/request as test_request

pub fn tests() -> TestSuite {
  describe("request fixture", [
    it("creates POST request with body", fn() {
      let request =
        test_request.create_request_with_body(
          Post,
          "/users",
          "{\"name\":\"Alice\"}",
        )

      request.body
      |> should()
      |> be_equal(Text("{\"name\":\"Alice\"}"))
      |> or_fail_with("Body should be the JSON")
    }),
  ])
}
```

## Step 4: Test a controller

Controllers receive `Request`, `Context`, and `Services`:

#### A controller test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_users_controller_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{AppContext}
import dream/http/request.{Get}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/request as test_request
import snippets/testing_guide_users_controller as users_controller

pub fn tests() -> TestSuite {
  describe("users_controller", [
    group("index", [
      it("returns 200 for valid request", fn() {
        let request = test_request.create_request(Get, "/users")
        let context = AppContext("test-id")

        users_controller.index(request, context, EmptyServices).status
        |> should()
        |> be_equal(200)
        |> or_fail_with("Should return 200")
      }),
    ]),
  ])
}
```

## Step 5: Test a middleware

Test middleware with mock `next` functions:

#### A middleware test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_auth_middleware_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{AppContext}
import dream/http/header.{Header}
import dream/http/request.{Get, Request}
import dream/http/response.{Response, Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/request as test_request
import gleam/option
import snippets/testing_guide_auth_middleware as auth

fn success_handler(_request, _context, _services) {
  Response(200, Text("Success"), [], [], option.None)
}

pub fn tests() -> TestSuite {
  describe("auth middleware", [
    it("returns 401 without token", fn() {
      let request = test_request.create_request(Get, "/protected")
      let context = AppContext("test-id")

      auth.middleware(request, context, EmptyServices, success_handler).status
      |> should()
      |> be_equal(401)
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
      |> be_equal(200)
      |> or_fail_with("Should pass with valid token")
    }),
  ])
}
```

## Step 6: Test a model

Test business logic without HTTP:

#### A model test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_user_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_error, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import snippets/testing_guide_user as user

pub fn tests() -> TestSuite {
  describe("user", [
    group("validate_email", [
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

## Step 7: Set up and tear down

### before_each / after_each

Run setup/teardown for each test in a group:

#### Setup and teardown for each test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_before_each.gleam#L1-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{after_each, before_each, describe, it}
import gleam/string

pub fn tests() -> TestSuite {
  describe("record tests", [
    before_each(fn() {
      // Reset test state
      Ok(Nil)
    }),
    after_each(fn() {
      // Cleanup
      Ok(Nil)
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
      |> be_equal(Ok("Alicia"))
      |> or_fail_with("Should update record")
    }),
  ])
}
```

### before_all / after_all

Run once before/after all tests in a group:

#### Setup and teardown once for a group <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_before_all.gleam#L1-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/dream
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status.{ok}
import dream/router.{route, router}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{after_all, before_all, describe, it}
import fixtures/request as test_request

pub fn tests() -> TestSuite {
  describe("server tests", [
    before_all(fn() {
      // Start shared resources once, such as a server
      Ok(Nil)
    }),
    after_all(fn() {
      // Stop them
      Ok(Nil)
    }),
    it("responds to GET /", fn() {
      let request = test_request.create_request(Get, "/")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> be_equal(200)
      |> or_fail_with("Should return 200")
    }),
    it("responds to GET /users", fn() {
      let request = test_request.create_request(Get, "/users")

      dream.route_request(app_router(), request, Nil, Nil).status
      |> should()
      |> be_equal(200)
      |> or_fail_with("Should return 200")
    }),
  ])
}
```

## Step 8: Test against real services

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
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{before_each, describe, it}
import gleam/result
import simplifile

const test_directory = "tmp/testing_guide_integration"

pub fn tests() -> TestSuite {
  describe("file storage integration", [
    before_each(fn() {
      // Delete files from earlier runs
      case simplifile.delete_all([test_directory]) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error("Could not delete test files")
      }
    }),
    it("saves user to disk", fn() {
      // Uses the real file system
      save_user(test_directory, "alice", "Alice")
      |> should()
      |> be_equal(Ok("Alice"))
      |> or_fail_with("Should read back the saved user")
    }),
  ])
}
```


## Step 9: Test the whole app through its routes

`dream.route_request` does what the server does with a request: it finds the route by method and path, runs its middleware and its controller, and returns the response. Give it your router and the context and services for the test. This is the test from [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html):

### Test the routes of an app <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_getting_started_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Getting started guide: the test of the app
////
//// In your project this is test/hello_dream_test.gleam, and the import of
//// the app is `import hello_dream as app`.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Post, Request}
import dream/http/response.{Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_getting_started_app as app

// gleam test runs this: it runs the tests and prints the report
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

// A request with no body, headers or cookies
fn request_to(method: request.Method, path: String) -> Request {
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
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

// Sends the request through the routes of the app, as the server does
fn send(request: Request) -> response.Response {
  dream.route_request(app.app_router(), request, EmptyContext, EmptyServices)
}

pub fn tests() -> TestSuite {
  describe("hello app", [
    it("answers GET / with 200", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("GET / should answer 200")
    }),
    it("answers GET / with Hello, World!", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Hello, World!"))
      |> or_fail_with("GET / should answer Hello, World!")
    }),
    it("answers an unknown path with 404", fn() {
      // Arrange
      let request = request_to(Get, "/missing")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(404)
      |> or_fail_with("GET /missing should answer 404")
    }),
    it("answers POST / with 405", fn() {
      // Arrange
      let request = request_to(Post, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(405)
      |> or_fail_with("POST / should answer 405")
    }),
  ])
}
```

### The report of the passing run <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_getting_started_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
hello app
  ✓ answers GET / with 200
  ✓ answers GET / with Hello, World!
  ✓ answers POST / with 405
  ✓ answers an unknown path with 404

Summary: 4 run, 0 failed, 4 passed in 0ms
```

## When a test fails

A test that expects `200` from a path with no route fails. Each failure names the test, the matcher, your message, and both values:

### A failing test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_testing_failing_test.gleam#L35-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("hello app", [
    it("answers GET /about with 200", fn() {
      // Arrange
      let request = get("/about")

      // Act
      let response =
        dream.route_request(
          app.app_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("GET /about should answer 200")
    }),
  ])
}
```

### The report of the failure <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_testing_failing_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
hello app
  ✗ answers GET /about with 200
    be_equal
      Message: GET /about should answer 200
      Expected: 200
      Actual:   404

Summary: 1 run, 1 failed, 0 passed in 0ms
```

With `runner.exit_on_failure()` in the entry point, the run then ends with status 1, so `gleam test` and CI fail too.

## How to write a good test

### Black Box Testing

Test public interfaces, not implementation details:

#### Good and bad black box tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L55-L75"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn black_box_tests() -> TestSuite {
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
      |> be_equal("Alice")
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

#### Focused tests and a test with two assertions <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L77-L110"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn one_assertion_tests() -> TestSuite {
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
      |> be_equal("Alice")
      |> or_fail_with("Name should be Alice")
    }),
  ])
}

pub fn multiple_assertions_test() -> UnitNode {
  // ❌ Bad - multiple assertions
  it("creates user correctly", fn() {
    let result = create_user("Alice", "alice@example.com")
    let _ = result |> should() |> be_ok() |> or_fail_with("Should create user")
    // And then another assertion...
    result
    |> should()
    |> be_ok()
    |> extract_name()
    |> be_equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}
```

In the bad test, `let _ =` throws away the result of the first assertion.
dream_test never sees it, so that check can fail and the test still passes.


### Arrange, Act, Assert

Every test follows AAA with blank lines between sections:

#### An Arrange, Act, Assert test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/testing_guide_examples.gleam#L112-L126"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn arrange_act_assert_test() -> UnitNode {
  it("uppercases string", fn() {
    // Arrange
    let input = "hello"

    // Act
    let result = string.uppercase(input)

    // Assert
    result
    |> should()
    |> be_equal("HELLO")
    |> or_fail_with("Should uppercase")
  })
}
```

## What to Test

### Do test

- Public API functions
- Business logic
- Error handling
- Edge cases (empty strings, zero, None)
- Integration points

### Don't test

- Private functions directly
- Third-party libraries
- Simple getters/setters
- Configuration objects (unless validation logic)

## Run the tests

In your app, run `gleam test`. Dream's own unit tests run with this line of `scripts/check.sh`, which CI runs. It also measures the line coverage:

### Run the unit tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/check.sh#L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make test-unit
```

### Coverage

All functions in `src/dream/` must have test coverage. If a private function
isn't reachable through public functions, it's dead code: delete it.

### Tips

1. **Write tests first** (TDD) or immediately after
2. **One assertion per test** for clear failures
3. **Test edge cases**: empty, zero, negative, None
4. **Test error paths**: what happens when things fail?
5. **Keep tests fast**: slow tests don't get run
6. **Use fixtures**: don't repeat test data setup


## Common pitfalls

- **Two assertions in one test.** `let _ =` on the first matcher throws its result away, so the test can pass while the first check fails. One assertion per test.
- **A test server left running.** Stop every handle of `listen_with_handle`, or the next run can't take the port.
- **Testing private functions.** Test through the public function that uses them. A private function no public function reaches is dead code.
- **Tests that depend on order.** Each test builds its own request and services. Don't share state between tests through a database row or a file without resetting it in a hook.
- **A slow unit test.** If a unit test needs a database or the network, it's an integration test. Move it, so the fast tests stay fast.

## Where to go next

- [Dream Test on HexDocs](https://hexdocs.pm/dream_test/3.0.0/).
- [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html): a middleware test through the routes.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): an operation test with test services, and Cucumber scenarios against PostgreSQL.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): a real server in a test.
