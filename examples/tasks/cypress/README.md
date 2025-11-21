# E2E Testing with Cypress

End-to-end tests for the Tasks example application using Cypress.

## Quick Start

**Run all E2E tests:**
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
```bash
make e2e-open
```

## Prerequisites

- **Node.js 16+** - For Cypress
- **Docker Desktop** - For PostgreSQL database
- **npm** - Package manager

## Setup

### 1. Install Cypress

```bash
make e2e-install
```

This installs Cypress and TypeScript dependencies.

### 2. Ensure Database is Running

The E2E tests require a running database. The `make e2e-test` command handles this automatically, but if running tests manually:

```bash
make db-up
make migrate
```

## Running Tests

### Full E2E Test Suite

```bash
make e2e-test
```

This is the recommended way to run tests. It handles all setup and teardown automatically.

### Interactive Mode (Development)

For developing and debugging tests:

```bash
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

```bash
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
- **Video**: Enabled (disabled in headless mode)
- **Screenshots**: Taken after each test (pass or fail)

## Screenshots and Videos

- **Screenshots**: `cypress/screenshots/` - Full page screenshots after each test
- **Videos**: `cypress/videos/` - Video recordings (only in headed mode)

Clean artifacts with:
```bash
make e2e-clean
```

## Writing New Tests

1. Create test file in `cypress/e2e/<feature>.cy.ts`
2. Use custom commands for HTMX interactions
3. Follow existing test patterns

Example:

```typescript
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

Since this application uses HTMX for dynamic updates, tests need to wait for HTMX requests to complete:

```typescript
// After form submission
cy.get('form').submit()
cy.waitForHtmx()

// After button click that triggers HTMX
cy.get('button').click()
cy.waitForHtmxSwap('#target-element')
```

## Troubleshooting

### "Cannot connect to server"

**Problem**: Test server isn't running

**Solution**: Use `make e2e-test` which starts the server automatically, or start manually:
```bash
make db-up
make migrate
make build
make run
```

### "Database connection failed"

**Problem**: Database not running

**Solution**:
```bash
make db-up
```

### "Cypress not found"

**Problem**: Cypress not installed

**Solution**:
```bash
make e2e-install
```

### Tests timing out

**Problem**: HTMX requests taking too long

**Solution**: Increase timeout in `cypress.config.ts`:
```typescript
defaultCommandTimeout: 15000, // Increase from 10000
```

## CI/CD Integration

For CI/CD pipelines, use:

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

