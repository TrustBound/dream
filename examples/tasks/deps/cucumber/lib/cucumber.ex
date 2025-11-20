defmodule Cucumber do
  @moduledoc """
  A behavior-driven development (BDD) testing framework for Elixir using Gherkin syntax.

  Cucumber is a testing framework that allows you to write executable specifications
  in natural language. It bridges the gap between technical and non-technical stakeholders
  by allowing tests to be written in plain language while being executed as code.

  ## Setup

  Add to your `test_helper.exs`:

      Cucumber.compile_features!()

  ## File Structure

  By default, Cucumber expects the following structure:

      test/
        features/
          authentication.feature
          shopping.feature
          step_definitions/
            authentication_steps.exs
            shopping_steps.exs
            common_steps.exs
          support/
            hooks.exs

  ## Configuration

  You can customize paths in `config/test.exs`:

      config :cucumber,
        features: ["test/features/**/*.feature"],
        steps: ["test/features/step_definitions/**/*.exs"]

  ## Step Definitions

  Create step definition modules using `Cucumber.StepDefinition`:

      defmodule AuthenticationSteps do
        use Cucumber.StepDefinition

        step "I am logged in as {string}", %{args: [username]} = context do
          {:ok, Map.put(context, :current_user, username)}
        end
      end

  ## Running Tests

  Cucumber tests run with `mix test` and can be filtered using tags:

      # Run all tests including Cucumber
      mix test

      # Run only Cucumber tests
      mix test --only cucumber

      # Exclude Cucumber tests
      mix test --exclude cucumber

  ## Key Features

  * Auto-discovery of features and step definitions
  * Integration with ExUnit's tagging system
  * Context passing between steps
  * Support for data tables and doc strings
  * Rich error reporting with suggestions
  """

  @doc """
  Discovers and compiles all cucumber features into ExUnit tests.

  This function should be called in your `test_helper.exs` file.

  ## Options

    * `:features` - List of patterns for feature files
    * `:steps` - List of patterns for step definition files
    * `:support` - List of patterns for support files

  ## Examples

      # Use default paths
      Cucumber.compile_features!()

      # Use custom paths
      Cucumber.compile_features!(
        features: ["test/acceptance/**/*.feature"],
        steps: ["test/acceptance/steps/**/*.exs"]
      )
  """
  def compile_features!(opts \\ []) do
    modules = Cucumber.Compiler.compile_features!(opts)

    # Return the compiled module names for debugging
    modules
  end
end
