# Integration Tests

This directory contains Cucumber-based integration tests for the tasks example.

## Setup

The integration tests use Elixir and Cucumber. Dependencies are managed via `mix.exs` in the example root.

## Running Tests

From the example root directory:

```bash
make test-integration
```

This will:
1. Start the database (via docker-compose)
2. Run migrations
3. Generate SQL code (Squirrel)
4. Compile Matcha templates
5. Build the Gleam application
6. Start the server in the background
7. Run the Cucumber tests
8. Clean up (stop server, stop database)

## Running a Specific Feature

You can run a specific feature file by setting the `CUCUMBER_FEATURE` environment variable:

```bash
CUCUMBER_FEATURE="test/integration/features/tasks.feature" make test-integration
```

## Test Structure

- `features/` - Gherkin feature files describing test scenarios
- `features/step_definitions/` - Elixir step definitions that implement the steps
- `support/` - Helper modules for database and test utilities

## Writing Tests

### Feature Files

Feature files use Gherkin syntax. See `features/tasks.feature` for examples.

### Step Definitions

Step definitions are in `features/step_definitions/`. Each file defines steps using the `Cucumber.StepDefinition` module.

### Support Modules

- `support/test_db.ex` - Database connection pool and cleanup utilities
- `support/test_helpers.ex` - General test helper functions

## Environment Variables

Tests use the `DATABASE_URL` environment variable, which defaults to:
`postgres://postgres:postgres@localhost:5437/tasks_db`

You can override this by setting the variable before running tests.

