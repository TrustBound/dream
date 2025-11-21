# Hooks

Cucumber for Elixir provides hooks that allow you to run code before and after scenarios. This is useful for setup and teardown operations like database transactions, authentication, or any other cross-cutting concerns.

## Overview

Hooks are defined in support files placed in `test/features/support/` and are automatically discovered and executed at the appropriate times during test execution.

## Defining Hooks

To define hooks, create a module that uses `Cucumber.Hooks`:

```elixir
# test/features/support/database_support.exs
defmodule DatabaseSupport do
  use Cucumber.Hooks

  # Global hook - runs before every scenario
  before_scenario context do
    # Your setup code here
    {:ok, Map.put(context, :setup_done, true)}
  end

  # Tagged hook - only runs for scenarios with @database tag
  before_scenario "@database", context do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)

    if context.async do
      Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    end

    {:ok, context}
  end

  # After hooks run in reverse order of definition
  after_scenario _context do
    # Cleanup code
    :ok
  end
end
```

## Hook Types

### Before Scenario Hooks

Run before each scenario:

```elixir
# Global before hook
before_scenario context do
  # Runs before every scenario
  {:ok, context}
end

# Tagged before hook
before_scenario "@slow", context do
  # Only runs for scenarios tagged with @slow
  {:ok, Map.put(context, :timeout, 30_000)}
end
```

### After Scenario Hooks

Run after each scenario:

```elixir
# Global after hook
after_scenario context do
  # Runs after every scenario
  :ok
end

# Tagged after hook
after_scenario "@api", context do
  # Only runs for scenarios tagged with @api
  # Clean up API state
  :ok
end
```

## Return Values

Hooks support the same return values as step definitions:

- `:ok` - Keeps the context unchanged
- `{:ok, map}` - Merges the map into the context
- `%{} = map` - Merges the map into the context
- `{:error, reason}` - Fails the scenario before it starts

## Hook Execution Order

1. Before hooks run in the order they are defined
2. After hooks run in reverse order (last defined runs first)
3. Tagged hooks only run for scenarios with matching tags
4. Global hooks run for all scenarios

## Tag Inheritance

Feature-level tags are inherited by all scenarios in that feature:

```gherkin
@database
Feature: User Management
  # All scenarios inherit @database tag

Scenario: Create user
  # This scenario has @database tag
  Given a new user

@api
Scenario: API user creation
  # This scenario has both @database and @api tags
  Given an API request
```

## Context Variables

The context passed to hooks includes:

- `:scenario_name` - The name of the current scenario
- `:async` - Whether the feature is running in async mode
- `:step_history` - List of steps executed (empty in before hooks)
- Any data added by previous hooks or steps

## Practical Examples

### Database Setup

```elixir
defmodule DatabaseSupport do
  use Cucumber.Hooks

  before_scenario "@database", context do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)

    if context.async do
      Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    end

    {:ok, context}
  end
end
```

### Authentication

```elixir
defmodule AuthSupport do
  use Cucumber.Hooks

  before_scenario "@authenticated", context do
    user = MyApp.Factory.insert(:user)
    token = MyApp.Auth.generate_token(user)

    {:ok, Map.merge(context, %{
      current_user: user,
      auth_token: token
    })}
  end
end
```

### Performance Monitoring

```elixir
defmodule PerformanceSupport do
  use Cucumber.Hooks

  before_scenario "@performance", context do
    start_time = System.monotonic_time()
    {:ok, Map.put(context, :start_time, start_time)}
  end

  after_scenario "@performance", context do
    duration = System.monotonic_time() - context.start_time
    milliseconds = System.convert_time_unit(duration, :native, :millisecond)

    IO.puts("Scenario completed in #{milliseconds}ms")
    :ok
  end
end
```

## Configuration

By default, support files are loaded from `test/features/support/**/*.exs`. You can customize this in your config:

```elixir
# config/test.exs
config :cucumber,
  support: ["test/support/**/*.exs", "test/cucumber_support/**/*.exs"]
```

## Best Practices

1. **Keep hooks focused** - Each hook should have a single responsibility
2. **Use tags wisely** - Don't create too many specialized hooks
3. **Avoid side effects** - Hooks should be predictable and repeatable
4. **Clean up in after hooks** - Ensure proper cleanup even if scenarios fail
5. **Use context passing** - Share data between hooks and steps via context

## Troubleshooting

### Hooks not running

1. Ensure your support files are in the correct directory
2. Verify the module uses `Cucumber.Hooks`
3. Check that tags match exactly (including the @ symbol)
4. Confirm the file has a `.exs` extension

### Hook execution order

Remember that:
- Before hooks run in definition order
- After hooks run in reverse definition order
- Tagged hooks only run when tags match