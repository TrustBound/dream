# Testing Guide for Dream

This document describes the testing infrastructure for the Dream web framework.

## Test Suites

### Unit Tests (Gleam)

Located in `test/dream/`, these test the core framework functionality:

```bash
# Run all unit tests
make test

# Or directly
gleam test
```

**Coverage:**
- HTTP request/response handling
- Router matching and path parameters
- Error type conversions
- Parameter validation
- Context management
- Server integration

### Integration Tests (Cucumber/BDD)

Located in `examples/*/test/integration/`, these test end-to-end functionality:

```bash
# Run all integration tests (requires PostgreSQL on port 5435)
make test-examples

# Run specific example
cd examples/database && make test-integration
```

**Total: 63 integration tests across 7 examples**

| Example | Tests | What It Tests |
|---------|-------|---------------|
| **simple** | 4 | Basic routing, path parameters, 404 handling |
| **custom_context** | 8 | Auth, authorization, token validation |
| **static** | 10 | Static files, content types, security |
| **streaming** | 6 | Request/response streaming, chunked transfer |
| **rate_limiter** | 8 | Rate limiting, window behavior, headers |
| **database** | 15 | CRUD, validation, persistence, isolation |
| **multi_format** | 12 | JSON/CSV/HTML/HTMX, streaming CSV |

## Integration Test Framework

### Technology Stack

- **Cucumber**: BDD framework for Elixir
- **Gherkin**: Human-readable test scenarios
- **HTTPoison**: HTTP client for testing
- **Postgrex**: PostgreSQL client for database cleanup
- **ExUnit**: Elixir's test framework (runner)

### Test Structure

```
examples/simple/
├── test/integration/
│   ├── features/
│   │   ├── simple.feature              # Gherkin scenarios
│   │   └── step_definitions/
│   │       └── http_steps.exs          # Step implementations
│   ├── cucumber_test.exs               # ExUnit entry point
│   └── test_helper.exs                 # Cucumber configuration
├── mix.exs                              # Elixir dependencies
└── Makefile                             # test-integration target
```

### Example Gherkin Scenario

```gherkin
Feature: Simple Example

  Background:
    Given the server is running on port 3000

  Scenario: GET root endpoint returns hello world
    When I send a GET request to "/"
    Then the response status should be 200
    And the response should contain "Hello from Dream"
```

### Test Isolation

**Database Examples** (`database`, `multi_format`):
- Each scenario runs in a clean database state
- Background step truncates tables: `TRUNCATE users CASCADE`
- Seed data is reinserted for `multi_format`
- Unique emails generated per test to avoid conflicts

**Rate Limiter Example**:
- Each scenario uses a unique IP address
- Avoids rate limit interference between scenarios
- Simulates window reset behavior

## Running Tests Locally

### Prerequisites

```bash
# Install Elixir (for Cucumber tests)
brew install elixir  # macOS
# OR
apt-get install elixir  # Ubuntu

# Start PostgreSQL (for database examples)
docker-compose up -d  # from examples/database or examples/multi_format
```

### Run All Tests

```bash
# Unit tests
make test

# Integration tests (all examples)
make test-examples
```

### Run Specific Example

```bash
cd examples/database
make test-integration
```

### Debug Failed Tests

```bash
# Check server logs
tail -f /tmp/database_test.log

# Verify database connection
docker-compose exec postgres psql -U postgres -d dream_example_database_db

# Check for port conflicts
lsof -i:3000
```

## CI Integration

### GitHub Actions Workflow

The CI runs two jobs on every PR:

1. **test**: Unit tests, format check, module tests
2. **integration-tests**: All 63 example integration tests

See `.github/workflows/ci.yml` for configuration.

### PostgreSQL Service

CI uses a PostgreSQL 16 service on port 5435:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    ports:
      - 5435:5432
    options: --health-cmd pg_isready
```

### Environment Variables

Database examples use environment variables:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_database_db
POSTGRES_PORT=5435  # For test cleanup
```

### CI-Specific Behavior

- **No Docker Compose**: Uses GitHub Actions PostgreSQL service
- **Port 5435**: All database examples connect to this port in CI
- **Database cleanup**: Each scenario truncates tables
- **Sequential execution**: Examples run one at a time

## Test Quality Standards

### ✅ What Makes a Good Integration Test

1. **Test Isolation**: Each scenario is independent
2. **No Warnings**: Clean compilation
3. **Meaningful**: Tests real behavior, not implementation
4. **Comprehensive**: Happy path + error cases
5. **Fast**: Most tests complete in < 1 second
6. **Readable**: Gherkin scenarios are self-documenting

### ❌ Anti-Patterns to Avoid

1. **No cleanup**: Data persists between tests
2. **Shared state**: Tests interfere with each other
3. **Hardcoded IDs**: Assumes database state
4. **Weak assertions**: `response should contain ""`
5. **No error testing**: Only tests happy path

## Coverage

### What's Tested

✅ **HTTP Methods**: GET, POST, PUT, DELETE
✅ **Status Codes**: 200, 201, 400, 404, 429, 500
✅ **Content Types**: JSON, HTML, CSS, CSV, SVG
✅ **Streaming**: Request and response streaming
✅ **Authentication**: Token validation, role-based access
✅ **Rate Limiting**: Window behavior, headers
✅ **Database**: CRUD, validation, persistence
✅ **Static Files**: Serving, content types, security
✅ **Error Handling**: Invalid JSON, missing fields, not found

### What's NOT Tested (Out of Scope)

❌ Performance/load testing
❌ Stress testing (thousands of concurrent requests)
❌ Network failure simulation
❌ Long-running connection tests
❌ Browser/JavaScript interaction

## Adding New Tests

### For New Examples

1. Create Gherkin feature file:

```gherkin
# examples/your_example/test/integration/features/your_example.feature
Feature: Your Example

  Background:
    Given the server is running on port 3000

  Scenario: Your test scenario
    When I send a GET request to "/endpoint"
    Then the response status should be 200
```

2. Implement step definitions (or reuse existing):

```elixir
# examples/your_example/test/integration/features/step_definitions/http_steps.exs
defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias Jason

  @base_url "http://localhost:3000"

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    # Implementation
  end
end
```

3. Add Cucumber configuration:

```elixir
# examples/your_example/test/integration/test_helper.exs
Application.put_env(:cucumber, :features, ["test/integration/features/**/*.feature"])
Application.put_env(:cucumber, :steps, ["test/integration/features/step_definitions/**/*.exs"])
ExUnit.start(timeout: 30_000)
Cucumber.compile_features!()
```

4. Add test dependencies to `mix.exs`:

```elixir
defp deps do
  [
    {:cucumber, "~> 0.4.1", only: [:test]},
    {:httpoison, "~> 2.0", only: [:test]},
    {:jason, "~> 1.4", only: [:test]}
  ]
end
```

5. Add Makefile target:

```makefile
test-integration:
	@gleam build
	@gleam run -m main > /tmp/test.log 2>&1 &
	@SERVER_PID=$$!; \
	sleep 2; \
	mix deps.get && MIX_ENV=test mix test; \
	TEST_EXIT=$$?; \
	kill $$SERVER_PID 2>/dev/null || true; \
	exit $$TEST_EXIT
```

6. Add to CI workflow (`.github/workflows/ci.yml`)

### For Database Examples

Additionally:

1. Add Postgrex dependency
2. Implement database cleanup step
3. Handle migrations in Makefile
4. Use `POSTGRES_PORT` env var for CI compatibility

See `examples/database` for reference implementation.

## Continuous Integration

### Workflow Status

[![CI](https://github.com/TrustBound/dream/actions/workflows/ci.yml/badge.svg)](https://github.com/TrustBound/dream/actions/workflows/ci.yml)

### Jobs

1. **test**: Unit tests + module tests (~2-3 minutes)
2. **integration-tests**: All example tests (~3-5 minutes)

### On Every PR

- ✅ Code formatting check
- ✅ Gleam compilation
- ✅ Unit test suite
- ✅ Module test suite
- ✅ 63 integration tests

### Debugging CI Failures

1. **Check workflow logs**: GitHub Actions > CI > Failed job
2. **Reproduce locally**: `make test-examples`
3. **Check specific example**: `cd examples/database && make test-integration`
4. **Verify PostgreSQL**: Ensure service started correctly
5. **Check timeouts**: Server startup should complete in < 30s

## Performance Benchmarks

Integration test execution times (local M2 Mac):

- **simple**: 0.2s (4 tests)
- **custom_context**: 0.2s (8 tests)
- **static**: 0.03s (10 tests)
- **streaming**: 6.1s (6 tests - includes deliberate delays)
- **rate_limiter**: 0.04s (8 tests)
- **database**: 0.3s (15 tests)
- **multi_format**: 0.2s (12 tests)

**Total runtime**: ~7 seconds for 63 tests

## Future Improvements

Potential enhancements for reaching 11/10:

- [ ] Concurrent request tests (race conditions)
- [ ] Load testing (1000+ req/sec)
- [ ] Connection pool exhaustion tests
- [ ] Timeout behavior tests
- [ ] WebSocket integration tests
- [ ] File upload size limits
- [ ] Memory usage profiling
- [ ] Response time assertions

## Resources

- [Cucumber Elixir Documentation](https://hexdocs.pm/cucumber/)
- [HTTPoison Documentation](https://hexdocs.pm/httpoison/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Example Integration Tests](./examples/)

