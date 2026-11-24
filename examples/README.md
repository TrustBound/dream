# Dream Examples

This directory contains comprehensive examples demonstrating Dream's features and best practices.

## Examples Overview

| Example | Description | Database | Tests | Port |
|---------|-------------|----------|-------|------|
| [simplest](./simplest) | Minimal "Hello World" | No | Manual | 3000 |
| [simple](./simple) | Basic routing and path parameters | No | Integration | 3000 |
| [custom_context](./custom_context) | Authentication and authorization | No | Integration | 3000 |
| [static](./static) | Static file serving | No | Integration | 3000 |
| [streaming](./streaming) | Streaming responses | No | Integration | 3003 |
| [rate_limiter](./rate_limiter) | Rate limiting middleware | No | Integration | 3000 |
| [database](./database) | PostgreSQL with Squirrel | Yes | Integration | 3002 |
| [multi_format](./multi_format) | JSON/CSV/HTML/HTMX formats | Yes | Integration | 3000 |
| [streaming_capabilities](./streaming_capabilities) | Advanced streaming patterns | No | Integration | 3001 |
| [tasks](./tasks) | Full-featured task manager | Yes | Integration + Cypress | 3000 |

**Every example has automated integration tests.** `simplest` runs only the request of its README, the others also run Cucumber scenarios.

## Running Examples

### Quick Start (No Database)

#### Start the simple example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/simple
make run
```

### Database Examples

#### Start the database example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/start.sh#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/database

# Start PostgreSQL database
make db-up

# Run database migrations
make migrate

# Start the server
make run
```

## Testing

### Run All Integration Tests

From the repository root (requires PostgreSQL on port 5435). The integration job of CI runs it with this line of `scripts/ci-integration.sh`:

#### Run all integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/ci-integration.sh#L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make test-integration
```

### Run Individual Example Tests

From the repository root:

#### Run the tests of one example <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/simple && make test-integration)
```

## Integration Test Framework

All examples use **Cucumber** (BDD framework) with **HTTPoison** for HTTP testing:

- **Feature files**: Gherkin scenarios in `test/integration/features/*.feature`
- **Step definitions**: Elixir implementations in `test/integration/features/step_definitions/*.exs`
- **Test isolation**: Database cleanup between scenarios
- **CI-ready**: All tests run in GitHub Actions

### Example Test Structure

The `simple` example has these test files. Run the command in `examples/simple`:

#### List the test files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find test/integration mix.exs Makefile -type f | sort
```

#### The test files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L754-L764"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Makefile
mix.exs
test/integration/cucumber_test.exs
test/integration/features/simple.feature
test/integration/features/step_definitions/http_steps.exs
test/integration/readme.sh
test/integration/readme_http2.sh
test/integration/readme_http2_output.txt
test/integration/readme_output.txt
test/integration/start.sh
test/integration/test_helper.exs
```

- `features/*.feature`: the Gherkin scenarios. `features/step_definitions/http_steps.exs`: the step implementations.
- `cucumber_test.exs` and `test_helper.exs`: the ExUnit entry point and the Cucumber configuration.
- `start.sh`: starts the server as the README says.
- `readme.sh` and `readme_output.txt`: the commands of the README and their expected output. `readme_http2.sh` and `readme_http2_output.txt` do the same over HTTP/2.
- `mix.exs`: the Elixir test dependencies. `Makefile`: the `test-integration` target.

## CI Integration

Integration tests run automatically on all pull requests. The `integration-tests` job of `.github/workflows/ci.yml` starts PostgreSQL for the database examples:

### The PostgreSQL service of CI <a href="https://github.com/TrustBound/dream/blob/3.0.0/.github/workflows/ci.yml#L137-L148"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
  integration-tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: dream_example_database_db
        ports:
          - 5435:5432
```

The `tasks` job runs `make test-tasks` with its own PostgreSQL service on port 5437, and the `docker` job runs `make test-docker` for `examples/deployment`.

## Test Coverage

### Error Handling
✅ 400 Bad Request (invalid JSON, missing fields)
✅ 404 Not Found (non-existent resources)
✅ 500 Internal Server Error (database errors)

### Content Validation
✅ JSON structure and field verification
✅ CSV format validation
✅ HTML content verification
✅ Content-Type headers

### Security
✅ Path traversal protection
✅ Authentication/authorization
✅ Rate limiting

### Streaming
✅ Request streaming (file uploads)
✅ Response streaming (large files, real-time data)
✅ Chunked transfer encoding

### Database
✅ CRUD operations
✅ Data persistence
✅ Transaction handling
✅ Test isolation (cleanup between scenarios)

## Best Practices Demonstrated

1. **Flat controller pattern**: No nested cases, all named helper functions
2. **Type-safe SQL**: Using Squirrel for compile-time query validation
3. **Separation of concerns**: Models, Controllers, Views, Operations
4. **Middleware composition**: Logging, authentication, rate limiting
5. **Error handling**: Unified error type with proper status codes
6. **Test isolation**: Database cleanup and unique test data
7. **BDD testing**: Readable Gherkin scenarios with reusable steps

## Adding a New Example

1. Create directory: `examples/your_example/`
2. Add `gleam.toml`, `Makefile`, `src/main.gleam`
3. Create Cucumber tests:
   - `test/integration/features/your_example.feature`
   - `test/integration/features/step_definitions/http_steps.exs`
   - `test/integration/cucumber_test.exs`
   - `test/integration/test_helper.exs`
4. Add `mix.exs` with test dependencies
5. Add `test-integration` target to Makefile
6. Update `.github/workflows/ci.yml` to include your example
7. Update this README

## Troubleshooting

### Tests Hanging

Check for port conflicts:
```bash illustration
lsof -i:3000  # Check if port is in use
pkill -f "gleam run"  # Kill all Gleam processes
```

### Database Connection Errors

Verify PostgreSQL is running:
```bash illustration
docker-compose ps
docker-compose logs postgres
```

### Compilation Errors

Clean and rebuild:
```bash illustration
make clean
gleam deps download
gleam build
```

## Resources

- [Dream Documentation](../docs)
- [Build your first Dream server](../docs/guides/getting-started.md)
- [Testing Guide](../docs/guides/testing.md)
- [The CI workflow](../.github/workflows/ci.yml)
