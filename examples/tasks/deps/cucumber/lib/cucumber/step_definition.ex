defmodule Cucumber.StepDefinition do
  @moduledoc """
  Provides macros for defining cucumber step definitions.

  ## Usage

      defmodule AuthenticationSteps do
        use Cucumber.StepDefinition

        step "I am logged in as {string}", %{args: [username]} = context do
          {:ok, Map.put(context, :current_user, username)}
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Cucumber.StepDefinition, only: [step: 2, step: 3]

      # Track step definitions
      Module.register_attribute(__MODULE__, :cucumber_steps, accumulate: true)

      @before_compile Cucumber.StepDefinition
    end
  end

  @doc """
  Defines a step implementation.
  """
  defmacro step(pattern, context_var \\ {:_, [], nil}, do: block) do
    # Generate function name at compile time
    fun_name = :"step_#{:erlang.phash2(pattern)}"

    quote do
      # Store metadata about this step
      @cucumber_steps {unquote(pattern),
                       %{
                         function: unquote(fun_name),
                         line: unquote(__CALLER__.line),
                         file: unquote(__CALLER__.file)
                       }}

      # Define the actual step function
      def unquote(fun_name)(unquote(context_var)) do
        unquote(block)
      end
    end
  end

  defmacro __before_compile__(env) do
    steps =
      Module.get_attribute(env.module, :cucumber_steps, [])
      |> Enum.reverse()

    # Generate the step/2 function body
    match_clauses =
      for {pattern, metadata} <- steps do
        quote do
          {unquote(pattern), unquote(metadata.function)}
        end
      end

    step_function =
      quote do
        def step(context, step_text) do
          # List of patterns and their functions
          patterns = unquote(match_clauses)

          # Find the first matching pattern
          result =
            Enum.find_value(patterns, fn {pattern, fun_name} ->
              case Cucumber.Expression.match(step_text, Cucumber.Expression.compile(pattern)) do
                {:match, args} ->
                  # Add args to context and call the step function
                  context_with_args = Map.put(context, :args, args)
                  {:ok, apply(__MODULE__, fun_name, [context_with_args])}

                :no_match ->
                  nil
              end
            end)

          case result do
            {:ok, value} -> value
            nil -> raise "No step definition found for: #{step_text}"
          end
        end
      end

    quote do
      # Make steps available for discovery
      def __cucumber_steps__ do
        unquote(Macro.escape(steps))
      end

      # Define the step/2 function
      unquote(step_function)
    end
  end
end
