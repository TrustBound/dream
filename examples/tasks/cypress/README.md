# E2E Testing with Cypress

End-to-end tests for the Tasks example application using Cypress.

## Quick Start

**Run all E2E tests:**
### Run the E2E tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-test
```

This will:
1. Start the database
2. Run migrations
3. Build the application
4. Start the server
5. Run Cypress tests
6. Clean up (stop server and database)

**Open Cypress UI (interactive mode):**
```bash illustration
make e2e-open
```

## Prerequisites

- **Node.js 18 or later** - For Cypress 13 (CI uses Node.js 22)
- **npm** - Package manager
- **Docker Desktop** - For PostgreSQL database
- **psql**, the PostgreSQL client - Before each test, `make db-clear` empties the tables with it
- **Gleam, Erlang and the matcha binary** - `make e2e-test` builds the app and its templates

The first `make e2e-install` downloads the Cypress binary, about 560 MB, to the Cypress cache (`~/Library/Caches/Cypress` on macOS, `~/.cache/Cypress` on Linux). Git ignores `node_modules` and `package-lock.json`, and the cache is outside the repository.

## Setup

### 1. Install Cypress

#### Install Cypress <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-install
```

This installs Cypress and TypeScript dependencies.

### 2. Ensure Database is Running

The E2E tests require a running database. The `make e2e-test` command handles this automatically, but if running tests manually:

#### Start the database <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/start.sh#L5-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Start database
make db-up

# Run migrations
make migrate
```

## Running Tests

### Full E2E Test Suite

#### Run the E2E tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-test
```

This is the recommended way to run tests. It handles all setup and teardown automatically.

### Interactive Mode (Development)

For developing and debugging tests:

```bash illustration
# Start database and server manually
make db-up
make migrate
make build
make run  # In another terminal

# Open Cypress UI
make e2e-open
```

The Cypress UI allows you to:
- Select which tests to run
- Watch tests execute in real-time
- Inspect elements and network requests
- Debug with time-travel
- See screenshots and videos

### Run Tests Headlessly (CI/CD)

```bash illustration
# Assumes server is already running
make e2e-run
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make e2e-test` | **Complete automation** - Start everything, run tests, cleanup |
| `make e2e-install` | Install Cypress and dependencies |
| `make e2e-open` | Open Cypress interactive test runner |
| `make e2e-run` | Run all E2E tests headlessly (server must be running) |
| `make e2e-clean` | Clean Cypress artifacts (screenshots, videos) |

## Test Structure

Tests are organized in `cypress/e2e/`:

- `tasks.cy.ts` - Main test suite covering:
  - Task list display
  - Task creation
  - Task completion toggle
  - Task editing
  - Task deletion
  - Task reordering
  - Projects
  - Tags
  - Error handling

## Custom Commands

The tests use custom Cypress commands for HTMX interactions:

- `cy.waitForHtmx()` - Wait for HTMX request to complete
- `cy.waitForHtmxSwap(selector?)` - Wait for HTMX swap to complete

These are defined in `cypress/support/commands.ts`.

## Configuration

Cypress configuration is in `cypress.config.ts`:

- **Base URL**: `http://localhost:3000`
- **Viewport**: 1920x1080
- **Video**: Off. The `video` setting of the `e2e` block wins over `--config video=...` on the command line, so set it there to record a run
- **Screenshots**: Taken after each test (pass or fail)

## Screenshots and Videos

- **Screenshots**: `cypress/screenshots/` - Full page screenshots after each test
- **Videos**: `cypress/videos/` - Video recordings of `cypress run`, when `video` is `true` in `cypress.config.ts`

Clean artifacts with:
### Clean the artifacts <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-clean
```

## Writing New Tests

1. Create test file in `cypress/e2e/<feature>.cy.ts`
2. Use custom commands for HTMX interactions
3. Follow existing test patterns

Example:

```typescript illustration
describe('My Feature', () => {
  beforeEach(() => {
    cy.visit('/')
  })

  it('should do something', () => {
    cy.get('input[name="field"]').type('value')
    cy.get('form').submit()
    cy.waitForHtmx()
    cy.contains('Expected Result').should('be.visible')
  })
})
```

## HTMX Testing

Since this application uses HTMX for dynamic updates, tests need to wait for HTMX requests to complete. `cypress/support/commands.ts` adds two commands for it: call `cy.waitForHtmx()` after a form submission, and `cy.waitForHtmxSwap('#target-element')` after a click that swaps an element:

### The HTMX commands <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/cypress/support/commands.ts#L12-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```typescript

/**
 * Wait for HTMX request to complete
 * Just a small delay - Cypress auto-waits for network requests
 */
Cypress.Commands.add('waitForHtmx', () => {
  // Cypress automatically waits for network requests
  // Just a small delay for DOM updates
  cy.wait(300)
})

/**
 * Wait for HTMX swap to complete
 * Useful after form submissions or button clicks
 */
Cypress.Commands.add('waitForHtmxSwap', (selector?: string) => {
  // Cypress automatically waits for network requests
  // Just a small delay for DOM updates
  cy.wait(300)
})
```

## Troubleshooting

### "Cannot connect to server"

**Problem**: Test server isn't running

**Solution**: Use `make e2e-test` which starts the server automatically, or start manually:
#### Start the database and the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/start.sh#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/tasks

# Start database
make db-up

# Run migrations
make migrate

# Run the application
make run
```

### "Database connection failed"

**Problem**: Database not running

**Solution**:
#### Start the database <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/start.sh#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make db-up
```

### "Cypress not found"

**Problem**: Cypress not installed

**Solution**:
#### Install Cypress <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-install
```

### Tests timing out

**Problem**: HTMX requests taking too long

**Solution**: Increase the timeout in `cypress.config.ts`. Today it is 10 seconds:
#### The timeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/cypress.config.ts#L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```typescript
    defaultCommandTimeout: 10000,
```

## CI/CD Integration

For CI/CD pipelines, use:

### Run the E2E tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/e2e.sh#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make e2e-test
```

This command:
- Handles all setup/teardown
- Runs tests headlessly
- Exits with proper status codes
- Cleans up resources

## Related Documentation

- [Cypress Documentation](https://docs.cypress.io/)
- [Integration Tests](../test/integration/README.md) - Backend API tests
- [Tasks Example README](../README.md) - Application documentation

