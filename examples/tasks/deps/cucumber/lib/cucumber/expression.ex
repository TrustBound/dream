defmodule Cucumber.Expression do
  @moduledoc """
  Parser and matcher for Cucumber Expressions used in step definitions.

  Cucumber Expressions are a human-friendly alternative to regular expressions,
  allowing you to define step patterns with typed parameters. This module handles
  compiling these expressions to regular expressions and extracting/converting parameters.

  ## Parameter Types

  The following parameter types are supported:

  * `{string}` - Matches quoted strings ("example") and converts to string
  * `{int}` - Matches integers (42) and converts to integer
  * `{float}` - Matches floating point numbers (3.14) and converts to float
  * `{word}` - Matches a single word (no whitespace) and converts to string

  ## Examples

      # Matching a step with a string parameter
      "I click {string} button" would match:
      "I click \"Submit\" button"

      # Matching a step with multiple parameters
      "I add {int} items to my {word} list" would match:
      "I add 5 items to my shopping list"
  """

  @doc """
  Compiles a Cucumber Expression pattern into a regex and parameter converters.

  This function transforms a human-readable pattern with typed parameters
  into a regular expression for matching and a list of converter functions
  to transform the captured values to their appropriate types.

  ## Parameters

  * `pattern` - A string containing a Cucumber Expression pattern

  ## Returns

  Returns a tuple `{regex, converters}` where:
  * `regex` - A compiled regular expression for matching step text
  * `converters` - A list of functions to convert captured values to their appropriate types

  ## Examples

      iex> {regex, converters} = Cucumber.Expression.compile("I have {int} items")
      iex> Regex.match?(regex, "I have 42 items")
      true
  """
  def compile(pattern) do
    # Define parameter type patterns and converters
    parameter_types = %{
      "string" => {~s/"([^"]*)"/, & &1},
      "int" => {~s/(-?\\d+)/, &String.to_integer/1},
      "float" => {~s/(-?\\d+\\.\\d+)/, &String.to_float/1},
      "word" => {~s/([^\\s]+)/, & &1}
    }

    # Find parameter placeholders like {string}, {int}, etc.
    placeholder_regex = ~r/\{([^}]+)\}/

    # Replace parameter placeholders with their regex patterns and collect converters
    {regex_pattern, converters} =
      Regex.split(placeholder_regex, pattern, include_captures: true)
      |> Enum.reduce({"", []}, fn
        "{" <> rest, {pattern_acc, converters_acc} ->
          # Extract the parameter type from the capture (remove the trailing "}")
          type = String.replace(rest, "}", "")

          case Map.get(parameter_types, type) do
            {regex_part, converter} ->
              {pattern_acc <> regex_part, converters_acc ++ [converter]}

            nil ->
              raise "Unknown parameter type: #{type}"
          end

        plain_text, {pattern_acc, converters_acc} ->
          # Escape regex special characters in plain text
          escaped = Regex.escape(plain_text)
          {pattern_acc <> escaped, converters_acc}
      end)

    # Compile the final regex pattern
    regex = Regex.compile!("^#{regex_pattern}$")

    {regex, converters}
  end

  @doc """
  Matches a step text against a compiled Cucumber Expression.

  This function attempts to match step text against a compiled Cucumber Expression
  and extracts/converts any parameters if there's a match.

  ## Parameters

  * `text` - The step text to match against the pattern
  * `{regex, converters}` - A compiled Cucumber Expression from `compile/1`

  ## Returns

  Returns one of:
  * `{:match, args}` - If the text matches, where `args` is a list of converted parameter values
  * `:no_match` - If the text doesn't match the expression

  ## Examples

      iex> compiled = Cucumber.Expression.compile("I have {int} items")
      iex> Cucumber.Expression.match("I have 42 items", compiled)
      {:match, [42]}
      iex> Cucumber.Expression.match("I have no items", compiled)
      :no_match
  """
  def match(text, {regex, converters}) do
    case Regex.run(regex, text, capture: :all_but_first) do
      nil ->
        :no_match

      captures ->
        # Apply converters to captured values
        args =
          Enum.zip(captures, converters)
          |> Enum.map(fn {value, converter} -> converter.(value) end)

        {:match, args}
    end
  end
end
