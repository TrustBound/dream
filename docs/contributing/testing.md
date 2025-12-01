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

```gleam
import dream_test/unit.{type UnitTest, describe, it}
import dream_test/assertions/should.{equal, be_ok, or_fail_with, should}

pub fn tests() -> UnitTest {
  describe("module_name", [
    describe("function_name", [
      it("does X when Y", fn() {
        // Arrange
        let input = create_test_input()

        // Act
        let result = function_under_test(input)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Expected X")
      }),
    ]),
  ])
}
```

### Entry Point

Tests are registered in `test/dream_test.gleam`:

```gleam
import dream_test/runner.{run_all}
import dream_test/unit.{to_test_cases}
import dream_test/reporter/bdd.{report}
import gleam/io
import gleam/list

import dream/context_test
import dream/router_test
// ... other test modules

pub fn main() {
  [
    to_test_cases("dream/context", context_test.tests()),
    to_test_cases("dream/router", router_test.tests()),
    // ... other modules
  ]
  |> list.flatten
  |> run_all()
  |> report(io.print)
}
```

### Assertions

```gleam
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_none, be_ok, be_some, be_true,
  contain, contain_string, equal, or_fail_with, should,
}

// All assertions follow the pattern:
value |> should() |> matcher() |> or_fail_with("message")

// Matchers can be chained:
result |> should() |> be_ok() |> equal(expected) |> or_fail_with("msg")
```

### Custom Matchers

Located in `test/matchers/`, one per file:

```gleam
// test/matchers/extract_body_text.gleam
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
    _other -> non_text_body_failure()
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

Located in `test/fixtures/`:

```gleam
// test/fixtures/request.gleam
pub fn create_request(method: Method, path: String) -> Request { ... }
pub fn create_request_with_body(method: Method, path: String, body: String) -> Request { ... }

// test/fixtures/handler.gleam
pub fn test_handler(request, context, services) -> Response { ... }
pub fn id_param_handler(request, context, services) -> Response { ... }
```

### Lifecycle Hooks

```gleam
import dream_test/unit.{describe, it, before_each, after_each, before_all, after_all}
import dream_test/types.{AssertionOk}

describe("tests with setup", [
  before_each(fn() {
    // Runs before each test
    AssertionOk
  }),
  after_each(fn() {
    // Runs after each test
    AssertionOk
  }),
  it("test one", fn() { ... }),
  it("test two", fn() { ... }),
])
```

### Benchmarks

Located in `test/benchmarks/`:

```gleam
// test/benchmarks/router_benchmark.gleam
import dream_test/unit.{type UnitTest, describe, it}
import dream_test/types.{AssertionOk}
import gleam/io

pub fn tests() -> UnitTest {
  describe("router benchmarks", [
    it("100 routes lookup", fn() {
      let router = build_router(100)
      let result = benchmark(fn() { find_route(router, request) }, 10_000)
      
      io.println("[BENCH] 100-routes: " <> format_result(result))
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

```gleam
// ✅ Good - focused tests
describe("find_route", [
  it("returns route for exact path", fn() { ... }),
  it("extracts params from path", fn() { ... }),
])

// ❌ Bad - multiple assertions
it("finds route and extracts params", fn() {
  // Two things being tested
})
```

### No Nested Cases

```gleam
// ❌ Bad
case result {
  MatchOk(response) -> {
    case response.body {  // Nested!
      Text(text) -> ...
    }
  }
}

// ✅ Good
case result {
  MatchFailed(failure) -> MatchFailed(failure)
  MatchOk(response) -> extract_from_body(response.body)
}

fn extract_from_body(body) {
  case body {
    Text(text) -> MatchOk(text)
    _other -> failure()
  }
}
```

### Error Handling

Never discard errors:

```gleam
// ❌ Bad
case result {
  Ok(value) -> value
  Error(_) -> default  // Error details lost
}

// ✅ Good
case result {
  Ok(value) -> value
  Error(reason) -> handle_error(reason)
}
```

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
