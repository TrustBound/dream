defmodule Cucumber.Hooks do
  @moduledoc """
  Provides hooks for setup and teardown in Cucumber tests.

  Hooks can be defined globally or filtered by tags. They are executed
  in the order they are defined, with Before hooks running in definition
  order and After hooks running in reverse order.

  ## Examples

      defmodule DatabaseSupport do
        use Cucumber.Hooks

        # Global before hook - runs for all scenarios
        before_scenario context do
          # Setup code
          {:ok, Map.put(context, :setup, true)}
        end

        # Tagged before hook - only runs for @database scenarios
        before_scenario "@database", context do
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)

          if context.async do
            Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
          end

          {:ok, context}
        end

        # After hooks run in reverse order
        after_scenario _context do
          # Cleanup code
          :ok
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Cucumber.Hooks
      Module.register_attribute(__MODULE__, :cucumber_hooks, accumulate: true)
      @before_compile Cucumber.Hooks
    end
  end

  @doc """
  Defines a before_scenario hook that runs before each scenario.

  Can optionally be filtered by tag. The hook receives the test context
  and must return one of:

  - `{:ok, context}`
  - `:ok` (keeps context unchanged)
  - map (merged into context)
  """
  defmacro before_scenario(context_var, do: block) do
    func_name = :"before_scenario_#{:erlang.unique_integer([:positive])}"

    quote do
      def unquote(func_name)(unquote(context_var)), do: unquote(block)
      @cucumber_hooks {:before_scenario, nil, {__MODULE__, unquote(func_name)}}
    end
  end

  defmacro before_scenario(tag, context_var, do: block) when is_binary(tag) do
    func_name = :"before_scenario_#{:erlang.unique_integer([:positive])}"

    quote do
      def unquote(func_name)(unquote(context_var)), do: unquote(block)
      @cucumber_hooks {:before_scenario, unquote(tag), {__MODULE__, unquote(func_name)}}
    end
  end

  @doc """
  Defines an after_scenario hook that runs after each scenario.

  Can optionally be filtered by tag. After hooks run in reverse order
  of definition. The hook receives the test context.
  """
  defmacro after_scenario(context_var, do: block) do
    func_name = :"after_scenario_#{:erlang.unique_integer([:positive])}"

    quote do
      def unquote(func_name)(unquote(context_var)), do: unquote(block)
      @cucumber_hooks {:after_scenario, nil, {__MODULE__, unquote(func_name)}}
    end
  end

  defmacro after_scenario(tag, context_var, do: block) when is_binary(tag) do
    func_name = :"after_scenario_#{:erlang.unique_integer([:positive])}"

    quote do
      def unquote(func_name)(unquote(context_var)), do: unquote(block)
      @cucumber_hooks {:after_scenario, unquote(tag), {__MODULE__, unquote(func_name)}}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __cucumber_hooks__ do
        @cucumber_hooks |> Enum.reverse()
      end
    end
  end

  @doc false
  def collect_hooks(modules) do
    modules
    |> Enum.flat_map(fn module ->
      if function_exported?(module, :__cucumber_hooks__, 0) do
        module.__cucumber_hooks__()
      else
        []
      end
    end)
  end

  @doc false
  def filter_hooks(hooks, type, tags) do
    hooks
    |> Enum.filter(fn
      {^type, nil, _fun} ->
        true

      {^type, tag, _fun} ->
        # Handle both with and without @ prefix
        tag in tags or String.trim_leading(tag, "@") in tags

      _ ->
        false
    end)
    |> Enum.map(fn {_type, _tag, hook_ref} -> hook_ref end)
  end

  @doc false
  def run_before_hooks(hooks, context, tags) do
    hooks
    |> filter_hooks(:before_scenario, tags)
    |> Enum.reduce({:ok, context}, fn
      _hook, {:error, _} = error ->
        error

      {module, func_name}, {:ok, context} ->
        case apply(module, func_name, [context]) do
          :ok -> {:ok, context}
          {:ok, new_context} -> {:ok, new_context}
          %{} = new_context -> {:ok, Map.merge(context, new_context)}
          {:error, _} = error -> error
        end
    end)
  end

  @doc false
  def run_after_hooks(hooks, context, tags) do
    hooks
    |> filter_hooks(:after_scenario, tags)
    # After hooks run in reverse order
    |> Enum.reverse()
    |> Enum.each(fn {module, func_name} -> apply(module, func_name, [context]) end)
  end
end
