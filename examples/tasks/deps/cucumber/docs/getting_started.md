# Getting Started with Cucumber for Elixir

Cucumber for Elixir allows you to write executable specifications using natural language that bridges the gap between technical and non-technical stakeholders.

## Overview

The Cucumber framework allows you to write tests in a natural language format using Gherkin syntax. This approach enables:

- Behavior-driven development (BDD)
- Clear documentation of application behavior
- Tests that serve as living documentation
- Auto-discovery of feature files and step definitions

## Installation

Add `cucumber` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:cucumber, "~> 0.4.1"}
  ]
end
```

## Quick Start

### 1. Configure Test Helper

Add Cucumber to your `test/test_helper.exs`:

```elixir
ExUnit.start()
Cucumber.compile_features!()
```

### 2. Create a Feature File

Feature files use the Gherkin syntax and should be placed in `test/features/` with a `.feature` extension.

```gherkin
# test/features/user_authentication.feature
Feature: User Authentication

Background:
  Given the application is running

Scenario: User signs in with valid credentials
  Given I am on the sign in page
  When I enter "user@example.com" as my email
  And I enter "password123" as my password
  And I click the "Sign In" button
  Then I should be redirected to the dashboard
  And I should see "Welcome back" message
```

### 3. Create Step Definitions

Create step definitions in `test/features/step_definitions/` with a `.exs` extension:

```elixir
# test/features/step_definitions/authentication_steps.exs
defmodule AuthenticationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  # Step definitions
  step "the application is running" do
    # Setup code here
    %{app_started: true}
  end

  step "I am on the sign in page", context do
    # Navigate to sign in page
    Map.put(context, :current_page, :sign_in)
  end

  step "I enter {string} as my email", %{args: [email]} = context do
    # Code to enter email
    Map.put(context, :email, email)
  end

  step "I enter {string} as my password", %{args: [password]} = context do
    # Code to enter password
    Map.put(context, :password, password)
  end

  step "I click the {string} button", %{args: [button_text]} do
    # Code to click button
    {:ok, %{clicked: button_text}}
  end

  step "I should be redirected to the dashboard", context do
    # Assertions for redirection
    assert context.current_page == :dashboard
    context
  end

  step "I should see {string} message", %{args: [message]} do
    # Assertion for message
    assert_text(message)
    :ok
  end
end
```

### 4. Run Your Tests

Run your tests using the standard mix test command:

```bash
# Run all tests including Cucumber
mix test

# Run only Cucumber tests
mix test --only cucumber

# Run tests for a specific feature
mix test --only feature_user_authentication
```

## File Structure

Cucumber automatically discovers features and steps using this structure:

```
test/
  features/                      # Feature files
    user_authentication.feature
    shopping_cart.feature
    step_definitions/           # Step definition files
      authentication_steps.exs
      shopping_steps.exs
      common_steps.exs
```

## Async Test Execution

For features that don't share state, you can enable concurrent test execution by adding the `@async` tag:

```gherkin
# test/features/calculator.feature
@async
Feature: Calculator Operations
  Independent calculations that can run concurrently

Scenario: Addition
  Given I have numbers 10 and 20
  When I add them together
  Then the result should be 30

Scenario: Multiplication
  Given I have numbers 5 and 6
  When I multiply them
  Then the result should be 30
```

Async features run concurrently with other async tests, improving test suite performance. Only use `@async` for features that are truly independent and don't rely on test execution order.

When using Ecto, async tests work well with the SQL sandbox in shared mode. See your application's test setup for database configuration.

## Next Steps

For more detailed information about the Cucumber for Elixir framework, check out these guides:

- [Feature Files](./feature_files.md) - Learn how to write feature files with Gherkin syntax
- [Step Definitions](./step_definitions.md) - Learn how to implement step definitions
- [Error Handling](./error_handling.md) - Understanding error reporting and debugging
- [Best Practices](./best_practices.md) - Best practices and examples