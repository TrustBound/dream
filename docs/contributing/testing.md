# Testing Guide for Dream Contributors

Testing infrastructure and standards for the Dream web framework.

## Running Tests

```bash
# Everything (unit + integration)
make test

# Unit tests only (core + modules)
make test-unit

# Dream core only
make test-dream

# Integration tests only
make test-integration
```

## Unit Tests

### Framework

Dream uses [dream_test](https://hexdocs.pm/dream_test/), a BDD-style testing
framework with `describe`/`it` blocks and chainable assertions.

### Test Location

| Source | Test |
|--------|------|
| `src/dream/context.gleam` | `test/dream/context_test.gleam` |
| `src/dream/router.gleam` | `test/dream/router_test.gleam` |
| `modules/http_client/src/...` | `modules/http_client/test/...` |

### Test Structure

#### Test a function <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_structure.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{InternalServerError}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("dream/http/error", [
    describe("to_status_code", [
      it("returns 500 for InternalServerError", fn() {
        // Arrange
        let database_error = InternalServerError("Database connection failed")

        // Act
        let result = error.to_status_code(database_error)

        // Assert
        result
        |> should()
        |> equal(500)
        |> or_fail_with("Expected 500")
      }),
    ]),
  ])
}
```

### Entry Point

Tests are registered in `test/dream_test.gleam`:

#### Run the test modules <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_entry_point.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context_test
import dream/router_test
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_all}
import dream_test/unit.{to_test_cases}
import gleam/io
import gleam/list

// ... other test modules

pub fn main() {
  [
    to_test_cases("dream/context", context_test.tests()),
    to_test_cases("dream/router", router_test.tests()),
    // ... other modules
  ]
  |> list.flatten
  |> run_all()
  |> report(io.println)
}
```

The real `test/dream_test.gleam` also ends the pipe with
`runner.exit_on_failure()`, so that CI sees a failed test.
`exit_on_failure()` stops the BEAM with exit code 1 when a test fails, and
with exit code 0 when all tests pass. The tests run the example above, so it
leaves that call out.

### Assertions

#### Assert values <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_assertions.gleam#L3-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{NotFound}
import dream/http/params
import dream/http/request.{Get}
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_none, be_ok, be_some, be_true, contain,
  contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/int
import gleam/option.{Some}

pub fn tests() -> UnitTest {
  describe("assertions", [
    it("checks one value", fn() {
      // All assertions follow the pattern:
      // value |> should() |> matcher() |> or_fail_with("message")
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
    it("chains matchers", fn() {
      let request =
        test_request.create_request_with_params(Get, "/users/42", [
          #("id", "42"),
        ])

      // Matchers can be chained:
      params.require_int(request, "id")
      |> should()
      |> be_ok()
      |> equal(42)
      |> or_fail_with("Expected id 42")
    }),
    other_matcher_tests(),
  ])
}
```

### Custom Matchers

Located in `test/matchers/`, one per file:

#### Extract the body text of a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_matcher.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/response.{type Response, type ResponseBody, Text}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

pub fn extract_body_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> extract_from_body(response.body)
  }
}

fn extract_from_body(body: ResponseBody) -> MatchResult(String) {
  case body {
    Text(text) -> MatchOk(text)
    _non_text_body -> non_text_body_failure()
  }
}

fn non_text_body_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_body_text",
    message: "Expected Text body",
    payload: Some(CustomMatcherFailure(
      actual: "Non-text body type",
      description: "Body is not Text",
    )),
  ))
}
```

**Matcher Rules:**
- One matcher per file
- First parameter is `MatchResult(a)` (for pipe compatibility)
- No nested `case` statements—extract to helper functions
- Return `MatchResult(b)` for chaining

### Fixtures

Located in `test/fixtures/`. `request.gleam` builds requests
(`create_request`, `create_request_with_body`, `create_request_with_params`
and more). `handler.gleam` holds controllers for router tests
(`test_handler`, `id_param_handler` and more). A test uses them like this:

#### Use request and handler fixtures <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_fixtures.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context
import dream/dream
import dream/http/request.{Get}
import dream/http/response.{type Response}
import dream/router.{EmptyServices, route, router}
import fixtures/handler.{id_param_handler, test_handler}
import fixtures/request as test_request

pub fn show_home() -> Response {
  let request = test_request.create_request(Get, "/")

  router()
  |> route(method: Get, path: "/", controller: test_handler, middleware: [])
  |> dream.route_request(request, context.new_context("test"), EmptyServices)
}

pub fn show_user() -> Response {
  let request = test_request.create_request(Get, "/users/42")

  router()
  |> route(
    method: Get,
    path: "/users/:id",
    controller: id_param_handler,
    middleware: [],
  )
  |> dream.route_request(request, context.new_context("test"), EmptyServices)
}
```

### Lifecycle Hooks

#### Run code before and after each test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_hooks.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{BadRequest, NotFound}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}

pub fn tests() -> UnitTest {
  describe("tests with setup", [
    before_each(fn() {
      // Runs before each test
      AssertionOk
    }),
    after_each(fn() {
      // Runs after each test
      AssertionOk
    }),
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
    it("returns 400 for BadRequest", fn() {
      error.to_status_code(BadRequest("Invalid email format"))
      |> should()
      |> equal(400)
      |> or_fail_with("Expected 400")
    }),
  ])
}
```

dream_test also has `before_all` and `after_all`, but they run only in suite
mode (`to_test_suite` with `run_suite`). `test/dream_test.gleam` uses
`to_test_cases` with `run_all`, which ignores them without an error, so use
`before_each` and `after_each` in Dream's tests.

### Benchmarks

Located in `test/benchmarks/`:

#### Time router lookups <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_benchmark.gleam#L3-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http/request.{type Request, Get}
import dream/router.{type EmptyServices, type Router}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{test_handler}
import fixtures/request as test_request
import gleam/float
import gleam/int
import gleam/io

pub fn tests() -> UnitTest {
  describe("router benchmarks", [
    it("100 routes lookup", fn() {
      let resource_router = build_router(100)
      let request = test_request.create_request(Get, "/resources/99")
      let elapsed = time_lookups(resource_router, request, 10_000)

      io.println("[BENCH] 100-routes: " <> format_result(elapsed, 10_000))
      AssertionOk
    }),
  ])
}
```

**Benchmark Output:** Self-identifying single lines for parallel execution:
```
[BENCH] 100-first: 11815μs total, 1.18μs/lookup (10000 iterations)
```

## Integration Tests

### Technology Stack

- **Cucumber**: BDD framework for Elixir
- **Gherkin**: Human-readable scenarios
- **HTTPoison**: HTTP client
- **Postgrex**: PostgreSQL client

### Location

```
examples/simple/
├── test/integration/
│   ├── features/
│   │   ├── simple.feature
│   │   └── step_definitions/
│   │       └── http_steps.exs
│   ├── cucumber_test.exs
│   └── test_helper.exs
├── mix.exs
└── Makefile
```

### Example Scenario

```gherkin
Feature: Simple Example

  Background:
    Given the server is running on port 3000

  Scenario: GET root returns hello
    When I send a GET request to "/"
    Then the response status should be 200
    And the response should contain "Hello from Dream"
```

### Running Integration Tests

```bash
# All integration tests
make test-integration

# Specific example
cd examples/database && make test-integration

# Specific module
cd modules/mock_server && make test-integration
```

### Test Isolation

**Database examples:** Each scenario truncates tables and reseeds data.

**Rate limiter:** Each scenario uses unique IP to avoid interference.

## Test Standards

### Requirements

| Requirement | Unit Tests | Integration Tests |
|-------------|------------|-------------------|
| External dependencies | ❌ None | ✅ Allowed |
| Speed | Milliseconds | Seconds OK |
| Determinism | Required | Required |
| Cleanup | N/A | Required |

### Naming Convention

```
<function_name>_<condition>_<expected_result>
```

Examples:
- `creates user with valid data`
- `returns error for missing field`
- `extracts param from path`

### One Assertion Per Test

#### Focused tests and a test with two assertions <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_standards.gleam#L24-L68"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ✅ Good - focused tests
pub fn focused_tests() -> UnitTest {
  describe("find_route", [
    it("returns route for exact path", fn() {
      let request = test_request.create_request(Get, "/users")
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> or_fail_with("Expected a route for /users")
    }),
    it("extracts params from path", fn() {
      let request = test_request.create_request(Get, "/users/42")
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "42")])
      |> or_fail_with("Expected the id param")
    }),
  ])
}

// ❌ Bad - multiple assertions
pub fn unfocused_test() -> UnitTest {
  it("finds route and extracts params", fn() {
    // Two things being tested
    let request = test_request.create_request(Get, "/users/42")
    let route_found =
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> or_fail_with("Expected a route for /users/42")
    let params_extracted =
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "42")])
      |> or_fail_with("Expected the id param")
    case route_found {
      AssertionOk -> params_extracted
      _failure -> route_found
    }
  })
}
```

### No Nested Cases

#### A nested case and a helper function <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_standards.gleam#L70-L97"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ❌ Bad
pub fn extract_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> {
      case response.body {
        // Nested!
        Text(text) -> MatchOk(text)
        _non_text_body -> non_text_body_failure()
      }
    }
  }
}

// ✅ Good
pub fn extract_body_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> extract_from_body(response.body)
  }
}

fn extract_from_body(body: ResponseBody) -> MatchResult(String) {
  case body {
    Text(text) -> MatchOk(text)
    _non_text_body -> non_text_body_failure()
  }
}
```

### Error Handling

Never discard errors:

#### A discarded error and a handled error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_testing_standards.gleam#L99-L114"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ❌ Bad
pub fn get_user_id(request: Request) -> Int {
  case require_int(request, "id") {
    Ok(id) -> id
    // Error details lost
    Error(_) -> 0
  }
}

// ✅ Good
pub fn show_user(request: Request) -> Response {
  case require_int(request, "id") {
    Ok(id) -> text_response(200, "User " <> int.to_string(id))
    Error(reason) -> text_response(400, error.message(reason))
  }
}
```

`get_user_id` returns `0` when the id is missing or is not an integer, so the
caller cannot tell a bad request from user 0, and the reason is gone.
`show_user` sends the reason back in a 400 response.

## Coverage

### What's Tested

✅ HTTP methods, status codes, content types
✅ Routing, parameters, wildcards
✅ Streaming request/response
✅ Validation, error handling
✅ Cookies, headers
✅ Middleware chain

### Coverage Requirement

All functions in `src/dream/` must have test coverage. Unreachable private
functions are dead code—delete them.

## CI Integration

### GitHub Actions

Two jobs on every PR:
1. **unit-tests**: Format check, build, unit tests
2. **integration-tests**: Integration tests with PostgreSQL

### PostgreSQL Service

```yaml
services:
  postgres:
    image: postgres:16-alpine
    ports:
      - 5435:5432
```

### Environment

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_database_db
POSTGRES_PORT=5435
```

## Adding Tests

### New Unit Test Module

1. Create test file mirroring source structure
2. Export `tests() -> UnitTest` function
3. Register in `test/dream_test.gleam`
4. Run `gleam test` to verify

### New Custom Matcher

1. Create file in `test/matchers/`
2. First param is `MatchResult(a)`
3. Return `MatchResult(b)`
4. No nested cases
5. Import in test files as needed

### New Integration Test

1. Create `.feature` file
2. Implement step definitions
3. Add to `mix.exs` deps
4. Add Makefile target
5. Add to CI workflow

## Debugging

### Failed Unit Tests

```bash
# Run with full output
gleam test

# Check specific module
gleam test --module dream/router_test
```

### Failed Integration Tests

```bash
# Check server logs
tail -f /tmp/test.log

# Verify database
docker-compose exec postgres psql -U postgres -d test_db

# Check ports
lsof -i:3000
```

## Resources

- [dream_test documentation](https://hexdocs.pm/dream_test/)
- [Cucumber Elixir](https://hexdocs.pm/cucumber/)
- [GitHub Actions](https://docs.github.com/en/actions)
