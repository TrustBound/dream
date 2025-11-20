# Step Definitions

Step definitions connect the Gherkin steps in your feature files to actual code. They're the glue between your natural language specifications and the implementation that tests your application.

## Creating Step Definition Files

Step definitions should be placed in `test/features/step_definitions/` with a `.exs` extension:

```elixir
# test/features/step_definitions/authentication_steps.exs
defmodule AuthenticationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  # Step definitions go here
end
```

## Basic Step Definition

Step definitions are created using the `step` macro:

```elixir
step "I am logged in as a customer", context do
  # Authentication logic here
  Map.put(context, :user, create_and_login_customer())
end
```

## Steps with Parameters

Cucumber supports several parameter types that can be used in step patterns. Parameters are accessed through pattern matching on the `args` field of the context:

### String Parameters

```elixir
step "I am on the product page for {string}", %{args: [product_name]} do
  # Navigate to product page
  %{current_page: :product, product_name: product_name}
end
```

### Integer Parameters

```elixir
step "I should have {int} items in my wishlist", %{args: [expected_count]} = context do
  # Assertion for wishlist count
  assert get_wishlist_count(context) == expected_count
  context
end
```

### Float Parameters

```elixir
step "the total price should be {float}", %{args: [expected_total]} = context do
  # Assertion for price
  assert_in_delta get_cart_total(context), expected_total, 0.01
  context
end
```

### Word Parameters

```elixir
step "I should see the {word} dashboard", %{args: [dashboard_type]} = context do
  # Assertion for dashboard type
  assert get_current_dashboard(context) == dashboard_type
  context
end
```

### Multiple Parameters

When a step has multiple parameters, you can pattern match on all of them:

```elixir
step "I transfer {float} from {string} to {string}", %{args: [amount, from_account, to_account]} do
  # Transfer logic
  %{transfer: %{amount: amount, from: from_account, to: to_account}}
end
```

## Working with Data Tables

In your feature file:
```gherkin
Given I have the following items in my cart:
  | Product Name    | Quantity | Price |
  | Smartphone      | 1        | 699.99|
  | Protection Plan | 1        | 79.99 |
```

In your step definitions:
```elixir
step "I have the following items in my cart:", context do
  # Access the datatable
  datatable = context.datatable

  # Access headers
  headers = datatable.headers  # ["Product Name", "Quantity", "Price"]

  # Access rows as maps
  items = datatable.maps
  # [
  #   %{"Product Name" => "Smartphone", "Quantity" => "1", "Price" => "699.99"},
  #   %{"Product Name" => "Protection Plan", "Quantity" => "1", "Price" => "79.99"}
  # ]

  # Process the items
  Map.put(context, :cart_items, items)
end
```

## Working with DocStrings

DocStrings allow you to pass multi-line text to a step:

In your feature file:
```gherkin
When I submit the following JSON:
  """
  {
    "name": "Test Product",
    "price": 29.99,
    "available": true
  }
  """
```

In your step definitions:
```elixir
step "I submit the following JSON:", context do
  # The docstring is available in context.docstring
  json_data = Jason.decode!(context.docstring)

  # Process the JSON
  Map.put(context, :submitted_data, json_data)
end
```

## Return Values

Step definitions must return one of the following values (matching ExUnit's setup behavior):

- `:ok` - Keeps the context unchanged
- A map - Merged into the existing context
- A keyword list - Merged into the existing context
- `{:ok, map_or_keyword_list}` - Merged into the existing context
- `{:error, reason}` - Fails the step with the given reason

## Reusable Step Definitions

You can create reusable step definitions that can be shared across multiple features:

```elixir
# test/features/step_definitions/common_steps.exs
defmodule CommonSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  step "I wait {int} seconds", %{args: [seconds]} = context do
    Process.sleep(seconds * 1000)
    context
  end

  step "I should see {string}", %{args: [text]} = context do
    assert page_contains_text?(context, text)
    context
  end
end
```

## Best Practices

1. **Keep steps focused**: Each step should do one thing well
2. **Use descriptive step patterns**: Make your steps readable and self-documenting
3. **Share common steps**: Create reusable step definitions for common actions
4. **Handle errors gracefully**: Return `{:error, reason}` for expected failures
5. **Maintain context**: Always return the context (or `:ok`) to maintain state between steps