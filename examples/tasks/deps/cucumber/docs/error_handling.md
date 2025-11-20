# Error Handling and Debugging

Cucumber for Elixir provides detailed error reporting to help debug test failures. This document explains how to handle and understand errors in your Cucumber tests.

## Enhanced Error Messages

The latest version of Cucumber for Elixir provides significantly enhanced error messages with:

- **Clickable file:line references** - Error messages include clickable links to the exact location in your feature files
- **Contextual information** - Feature file path, scenario name, and line numbers
- **Step execution history** - See which steps passed before the failure
- **Improved formatting** - Better readability for assertion errors and HTML elements

## Types of Errors

### Missing Step Definition

When a step in your feature file has no matching definition, the framework will provide a helpful error message with a clickable file reference:

```
** (Cucumber.StepError) No matching step definition found for step:

  When I try to use a step with no definition

in scenario "Missing Step Example" at test/features/example.feature:6

Please define this step with:

step "I try to use a step with no definition", context do
  # Your step implementation here
  context
end
```

The file:line format (e.g., `test/features/example.feature:6`) is clickable in most editors and terminals, taking you directly to the problematic line.

### Failed Step

When a step fails during execution (due to a failed assertion or an exception), you'll get an enhanced error message:

```
** (Cucumber.StepError) Step failed:

  Then the validation should succeed

in scenario "Form Submission" at test/features/forms.feature:12
matching pattern: "the validation should succeed"

Validation failed: invalid input data

Step execution history:
  ✓ Given a form to fill out
  ✓ When I submit invalid data
  ✗ Then the validation should succeed

Stacktrace:
  test/features/step_definitions/form_steps.exs:45: FormSteps."step: the validation should succeed"/1
```

The enhanced error message includes:
- Which step failed with the exact text from the feature file
- **Clickable file:line reference** to the scenario location (e.g., `test/features/forms.feature:12`)
- The step pattern that matched
- Clear error message from the step implementation
- **Visual step execution history** with ✓ for passed and ✗ for failed steps
- Full stacktrace for debugging

### Improved Assertion Error Formatting

When using ExUnit assertions that fail, the error messages are now extracted and formatted for better readability:

```
** (Cucumber.StepError) Step failed:

  Then I should see "Welcome" in the header

in scenario "Homepage Visit" at test/features/homepage.feature:8
matching pattern: "I should see {string} in the header"

Assertion failed:
Expected to find "Welcome" in:
<header>
  <h1>Hello World</h1>
</header>

Step execution history:
  ✓ Given I visit the homepage
  ✗ Then I should see "Welcome" in the header
```

### PhoenixTest HTML Element Formatting

When working with PhoenixTest and HTML elements, error messages now display HTML with proper indentation:

```
** (Cucumber.StepError) Step failed:

  When I click the "Submit" button

in scenario "Form Submission" at test/features/forms.feature:15
matching pattern: "I click the {string} button"

Element not found: button with text "Submit"

Available buttons in the page:
  <button class="btn-primary">
    Save Draft
  </button>
  <button class="btn-secondary" disabled>
    Cancel
  </button>

Step execution history:
  ✓ Given I am on the registration page
  ✓ When I fill in the form
  ✗ When I click the "Submit" button
```

### Syntax Errors in Feature Files

If there are syntax errors in your feature files, you'll get an error when the parser tries to process the file:

```
** (Cucumber.ParseError) Syntax error in feature file:

  test/features/invalid.feature:5

Expected a scenario or background but found:

  Invalid line that doesn't start with a Gherkin keyword
```

## Step Failure Handling

Step definitions can indicate failure in several ways:

### 1. Assertions

Using ExUnit assertions will cause the step to fail if the assertion fails:

```elixir
step "the total should be {float}", %{args: [total]} = context do
  assert context.cart_total == total
  :ok
end
```

### 2. Raising Exceptions

Any uncaught exception will cause the step to fail:

```elixir
step "I click the submit button", _context do
  raise "The submit button is disabled"
  :ok
end
```

### 3. Returning `{:error, reason}`

You can explicitly return an error tuple to fail a step:

```elixir
step "the payment should be successful", context do
  if context.payment_status == :success do
    :ok
  else
    {:error, "Expected payment to succeed, but got status: #{context.payment_status}"}
  end
end
```

## Debugging Tips

### 1. Leverage the Enhanced Error Messages

The new error formatting provides several features to help you debug:

- **Click the file:line references** to jump directly to the failing scenario
- **Review the step execution history** to understand what happened before the failure
- **Check the formatted HTML output** when debugging UI interactions
- **Read the extracted assertion messages** for clear failure reasons

### 2. Use IO.inspect for Debug Output

Insert `IO.inspect` calls to see the values of variables during test execution:

```elixir
step "I should see my order summary", context do
  IO.inspect(context, label: "Context in order summary step")
  assert context.order != nil
  :ok
end
```

### 3. Add Step Execution Logs

Log information about step execution:

```elixir
step "I complete the checkout process", context do
  IO.puts("Starting checkout process")
  # Checkout logic
  IO.puts("Completed checkout process")
  :ok
end
```

### 4. Examine the Full Context

Print the full context at any point to see the accumulated state:

```elixir
step "I check my context", context do
  IO.inspect(context, label: "Current context", pretty: true)
  :ok
end
```

### 5. Create Debug-Only Steps

Add steps specifically for debugging:

```elixir
step "I debug my test state", context do
  IO.puts("==== DEBUG STATE ====")
  IO.inspect(context.current_page, label: "Current Page")
  IO.inspect(context.user, label: "Current User")
  IO.inspect(context.cart_items, label: "Cart Items")
  IO.puts("==== END DEBUG ====")
  :ok
end
```

## Handling Flaky Tests

Sometimes tests can be inconsistent due to timing issues, especially with UI interactions:

```elixir
step "I should see the confirmation message", context do
  # Add delay or retry logic for UI-related assertions
  :timer.sleep(500)  # Give the UI time to update
  assert_text("Your order has been confirmed")
  :ok
end
```

Consider implementing retry logic for flaky steps:

```elixir
defp retry_until(function, max_attempts \\ 5, delay \\ 100) do
  Enum.reduce_while(1..max_attempts, nil, fn attempt, _acc ->
    case function.() do
      {:ok, result} -> {:halt, {:ok, result}}
      {:error, reason} ->
        if attempt == max_attempts do
          {:halt, {:error, reason}}
        else
          :timer.sleep(delay)
          {:cont, nil}
        end
    end
  end)
end

step "I should see the success notification", _context do
  result = retry_until(fn ->
    if element_visible?(".success-notification") do
      {:ok, true}
    else
      {:error, "Success notification not visible"}
    end
  end)

  case result do
    {:ok, _} -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

## Common Error Patterns and Solutions

| Error Pattern | Possible Cause | Solution |
|---------------|----------------|----------|
| Step not found | Step definition missing or typo in step | Create the missing step definition or correct the typo |
| Assertion failure | Expected value doesn't match actual | Check your test data and application logic |
| Timeout | Asynchronous operation didn't complete in time | Increase timeout or add retry logic |
| Element not found | UI element not rendered yet or selector wrong | Add delay, retry, or correct the selector |
| Context key missing | Previous step didn't set expected data | Ensure required context keys are set in earlier steps |