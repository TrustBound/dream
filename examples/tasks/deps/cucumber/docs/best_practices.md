# Best Practices for Cucumber Tests

This guide outlines best practices for writing and organizing your Cucumber tests to ensure they remain maintainable, readable, and effective.

## Feature File Organization

### Directory Structure

```
test/
├── features/                    # Feature files
│   ├── authentication/          # Feature grouping by domain
│   │   ├── login.feature
│   │   └── registration.feature
│   ├── shopping/               # Another domain
│   │   ├── cart.feature
│   │   └── checkout.feature
│   └── step_definitions/       # Step definition files
│       ├── authentication_steps.exs
│       ├── shopping_steps.exs
│       └── common_steps.exs
```

### Naming Conventions

- Use snake_case for feature file names
- Group related features into subdirectories
- Name step definition modules descriptively (e.g., `AuthenticationSteps`, `ShoppingSteps`)
- Use `.exs` extension for step definition files

## Writing Good Scenarios

### Scenario Best Practices

1. **Keep scenarios focused**: Each scenario should test one specific behavior
2. **Be consistent**: Use consistent language across scenarios
3. **Use concrete examples**: Prefer specific, realistic values to abstract placeholders
4. **Avoid technical details**: Keep scenarios in business language
5. **Keep them short**: Aim for 3-7 steps per scenario
6. **Use backgrounds wisely**: Only for truly common setup steps

### Example: Bad vs. Good

Bad:
```gherkin
Scenario: User interaction
  Given a user
  When the user does stuff
  Then the outcome is good
```

Good:
```gherkin
Scenario: Customer adds product to shopping cart
  Given I am logged in as "alice@example.com"
  And I am viewing the "iPhone 15 Pro" product page
  When I click "Add to Cart"
  Then I should see "iPhone 15 Pro" in my shopping cart
  And the cart total should be $999.00
```

## Step Definition Best Practices

### Keep Steps Reusable

Write generic steps that can be reused across features:

```elixir
# Good - reusable
step "I click {string}", %{args: [button_text]} = context do
  click_button(context, button_text)
end

# Less reusable - too specific
step "I click the red submit button on the login form", context do
  click_specific_button(context)
end
```

### Use the Context Effectively

Pass data between steps using the context:

```elixir
step "I create a product named {string}", %{args: [name]} = context do
  product = create_product(name: name)
  Map.put(context, :product, product)
end

step "I should see the product in my catalog", context do
  assert product_in_catalog?(context.product)
  context
end
```

### Organize Step Definitions

Group related steps in the same module:

```elixir
# test/features/step_definitions/authentication_steps.exs
defmodule AuthenticationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  # Login steps
  step "I am logged in as {string}", %{args: [email]} = context do
    user = login_user(email)
    Map.put(context, :current_user, user)
  end

  # Registration steps
  step "I register with email {string}", %{args: [email]} = context do
    user = register_user(email: email)
    Map.put(context, :new_user, user)
  end
end
```

## Common Patterns

### Data Setup Pattern

Create helper functions for common data setup:

```elixir
defmodule TestHelpers do
  def create_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test@example.com",
      name: "Test User"
    }

    attrs = Map.merge(default_attrs, attrs)
    # Create user logic
  end
end

# In your steps
step "a user exists with email {string}", %{args: [email]} do
  user = TestHelpers.create_user(email: email)
  %{user: user}
end
```

### Assertion Helpers

Create custom assertion helpers for cleaner steps:

```elixir
defmodule AssertionHelpers do
  import ExUnit.Assertions

  def assert_logged_in(context) do
    assert context[:current_user] != nil
    assert context[:session_token] != nil
  end

  def assert_product_visible(context, product_name) do
    assert product_name in get_visible_products(context)
  end
end
```

## Testing Tips

### Use Tags for Organization

Tag your scenarios for easy filtering:

```gherkin
@authentication @smoke
Scenario: Successful login
  Given I am on the login page
  When I enter valid credentials
  Then I should be logged in

@wip @slow
Scenario: Complex data processing
  Given a large dataset
  When I process the data
  Then the results should be accurate
```

Run specific tags:
```bash
mix test --only authentication
mix test --exclude wip
```

### Background vs. Helper Steps

Use backgrounds for truly common setup that applies to all scenarios:

```gherkin
Background:
  Given the system is initialized
  And default products exist

Scenario: View product catalog
  When I visit the catalog page
  Then I should see all products
```

### Handling Asynchronous Operations

For operations that might take time:

```elixir
step "I wait for the email to arrive", context do
  # Poll for the email with a timeout
  email = wait_for_email(context.current_user.email, timeout: 5_000)
  Map.put(context, :received_email, email)
end

defp wait_for_email(email, opts) do
  timeout = Keyword.get(opts, :timeout, 5_000)
  poll_interval = 100

  wait_until(timeout, poll_interval, fn ->
    check_email_arrived(email)
  end)
end
```

## Debugging Tips

1. **Leverage Enhanced Error Messages**: The framework now provides clickable file:line references in error messages that take you directly to the failing scenario
2. **Review Step Execution History**: Error messages include a visual history (✓ for passed, ✗ for failed) showing which steps executed before the failure
3. **Use IO.inspect in steps**: Temporarily add `IO.inspect(context)` to see the current state
4. **Run single scenarios**: Focus on one test at a time during debugging
5. **Use meaningful assertions**: Include context in assertion messages
6. **Take advantage of formatted HTML output**: When debugging PhoenixTest failures, the error messages now display HTML elements with proper indentation

```elixir
step "the order should be completed", context do
  order = context.order
  assert order.status == "completed",
         "Expected order #{order.id} to be completed, but was #{order.status}"
  context
end
```

When an error occurs, you'll see output like:
```
** (Cucumber.StepError) Step failed:

  Then the order should be completed

in scenario "Order Processing" at test/features/orders.feature:25
matching pattern: "the order should be completed"

Expected order 12345 to be completed, but was pending

Step execution history:
  ✓ Given I have items in my cart
  ✓ When I submit the order
  ✗ Then the order should be completed
```

The file reference `test/features/orders.feature:25` is clickable in most editors and terminals.