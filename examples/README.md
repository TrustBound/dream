# Dream Examples

This directory contains comprehensive examples demonstrating Dream's features and best practices.

## Examples Overview

| Example | Description | Database | Tests | Port |
|---------|-------------|----------|-------|------|
| [simplest](./simplest) | Minimal "Hello World" | No | Manual | 3000 |
| [simple](./simple) | Basic routing and path parameters | No | 4 ✅ | 3000 |
| [custom_context](./custom_context) | Authentication and authorization | No | 8 ✅ | 3000 |
| [static](./static) | Static file serving | No | 10 ✅ | 3000 |
| [streaming](./streaming) | Streaming responses | No | 6 ✅ | 3003 |
| [rate_limiter](./rate_limiter) | Rate limiting middleware | No | 8 ✅ | 3000 |
| [database](./database) | PostgreSQL with Squirrel | Yes | 15 ✅ | 3002 |
| [multi_format](./multi_format) | JSON/CSV/HTML/HTMX formats | Yes | 12 ✅ | 3000 |
| [streaming_capabilities](./streaming_capabilities) | Advanced streaming patterns | No | TBD | 3001 |
| [tasks](./tasks) | Full-featured task manager | Yes | Cucumber | 3000 |

**Total: 63 automated integration tests**

## Running Examples

### Quick Start (No Database)

```bash
cd examples/simple
make run
```

### Database Examples

```bash
cd examples/database

# Start PostgreSQL
docker-compose up -d

# Run migrations
make migrate

# Start server
make run
```

## Testing

### Run All Integration Tests

```bash
# From repository root (requires PostgreSQL on port 5435)
make test-examples
```

### Run Individual Example Tests

```bash
cd examples/simple
make test-integration
```

## Integration Test Framework

All examples use **Cucumber** (BDD framework) with **HTTPoison** for HTTP testing:

- **Feature files**: Gherkin scenarios in `test/integration/features/*.feature`
- **Step definitions**: Elixir implementations in `test/integration/features/step_definitions/*.exs`
- **Test isolation**: Database cleanup between scenarios
- **CI-ready**: All tests run in GitHub Actions

### Example Test Structure

```
examples/simple/
├── test/
│   └── integration/
│       ├── features/
│       │   ├── simple.feature           # Gherkin scenarios
│       │   └── step_definitions/
│       │       └── http_steps.exs       # Step implementations
│       ├── cucumber_test.exs            # ExUnit entry point
│       └── test_helper.exs              # Cucumber configuration
├── mix.exs                               # Elixir test dependencies
└── Makefile                              # test-integration target
```

## CI Integration

Integration tests run automatically on all pull requests:

```yaml
# .github/workflows/ci.yml includes:
jobs:
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:  # For database examples
```

See [Integration Tests CI Documentation](../.github/workflows/integration-tests.md) for details.

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
```bash
lsof -i:3000  # Check if port is in use
pkill -f "gleam run"  # Kill all Gleam processes
```

### Database Connection Errors

Verify PostgreSQL is running:
```bash
docker-compose ps
docker-compose logs postgres
```

### Compilation Errors

Clean and rebuild:
```bash
make clean
gleam deps download
gleam build
```

## Resources

- [Dream Documentation](../docs)
- [Quickstart Guide](../docs/quickstart.md)
- [Testing Guide](../docs/guides/testing.md)
- [CI Documentation](../.github/workflows/integration-tests.md)
