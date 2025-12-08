# Integration Tests

This directory contains Cucumber-based integration tests for the streaming capabilities example.

## Running Tests

Run integration tests:
```bash
make test-integration
```

This will:
1. Build the Gleam application
2. Start the server on port 3000
3. Run Cucumber tests against the running server
4. Stop the server when done

## Test Structure

- `features/` - Cucumber feature files describing test scenarios
- `features/step_definitions/` - Step definitions implementing the test steps
- `test_helper.exs` - Test configuration and setup
- `cucumber_test.exs` - Test module that runs Cucumber features

## Writing Tests

Add new scenarios to `features/streaming.feature` using Gherkin syntax:

```gherkin
Scenario: My new test
    When I send a POST request to "/endpoint" with body "data"
    Then the response status should be 200
```

Add new step definitions to `features/step_definitions/` as needed.






