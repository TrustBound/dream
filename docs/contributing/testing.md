# Testing Guide for Dream

This document describes the testing infrastructure for the Dream web framework.

## Test Suites

### Unit Tests (Gleam)

Located in `test/dream/` (core) and `modules/*/test/` (modules), these test framework functionality:

```bash
# Run all tests (unit + integration)
make test

# Run all unit tests (core + modules)
make test-unit

# Run only Dream core tests
make test-dream

# Or run specific tests directly
gleam test                              # Core only
cd modules/http_client && make test     # Module only
cd modules/mock_server && make test     # Module only
```

**Unit Test Coverage:**
- **Dream Core**: HTTP, routing, validation, context, server
- **dream_http_client**: HTTP client, streaming, error handling  
- **dream_mock_server**: Mock server configuration, lifecycle

### Integration Tests (Cucumber/BDD)

Located in `modules/*/test/integration/` and `examples/*/test/integration/`, these test end-to-end functionality:

```bash
# Run all integration tests (modules + examples, requires PostgreSQL on port 5435)
make test-integration

# Run specific example
cd examples/database && make test-integration

# Run specific module
cd modules/mock_server && make test-integration
```

**Integration Test Coverage:**

| Module/Example | What It Tests |
|----------------|---------------|
| **mock_server** (module) | Mock server endpoints, streaming, error handling |
| **simple** | Basic routing, path parameters, 404 handling |
| **custom_context** | Auth, authorization, token validation |
| **static** | Static files, content types, security |
| **streaming** | Request/response streaming, chunked transfer |
| **streaming_capabilities** | Advanced streaming, SSE, proxying |
| **rate_limiter** | Rate limiting, window behavior, headers |
| **database** | CRUD, validation, persistence, isolation |
| **multi_format** | JSON/CSV/HTML/HTMX, streaming CSV |

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
# Everything (unit + integration)
make test

# Only unit tests (core + modules)
make test-unit

# Only integration tests (modules + examples)
make test-integration

# Only Dream core tests
make test-dream
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

1. **unit-tests**: Format check, build, all unit tests (core + modules)
2. **integration-tests**: All integration tests (modules + examples)

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

1. **unit-tests**: Core + module unit tests
2. **integration-tests**: Module + example integration tests

### On Every PR

- ✅ Code formatting check
- ✅ Gleam compilation
- ✅ Unit tests (core + modules)
- ✅ Integration tests (modules + examples)

### Debugging CI Failures

1. **Check workflow logs**: GitHub Actions > CI > Failed job
2. **Reproduce locally**: 
   - Unit tests: `make test-unit`
   - Integration tests: `make test-integration`
3. **Check specific module/example**: `cd modules/mock_server && make test-integration`
4. **Verify PostgreSQL**: Ensure service started correctly (for database examples)
5. **Check timeouts**: Server startup should complete in < 30s

## Performance

Integration tests run quickly - typically completing in seconds. The `streaming` example takes longer due to deliberate delays to test timing behavior. Database examples include setup/teardown time.

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




