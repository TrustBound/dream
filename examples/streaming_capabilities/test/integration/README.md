# Integration Tests

This directory contains Cucumber-based integration tests for the streaming capabilities example.

## Running Tests

Run integration tests from the repository root:

### Run the integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/streaming_capabilities && make test-integration)
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

Add new scenarios to `features/streaming.feature` using Gherkin syntax. This one sends a body to the transforming endpoint:

### A scenario <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/test/integration/features/streaming.feature#L41-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
    Scenario: Echo transform with middleware converts input to uppercase and spaces to underscores
        When I send a POST request to "/echo_transform" with body "hello world"
        Then the response status should be 200
        And the response header "Content-Type" should be "text/plain"
        And the response should be "HELLO_WORLD"
```

Add new step definitions to `features/step_definitions/` as needed.






