defmodule JsonSteps do
  use Cucumber.StepDefinition

  alias Jason

  step "the response should be valid JSON", context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    case Jason.decode(response.body) do
      {:ok, _json} -> context
      {:error, reason} -> raise "Response is not valid JSON: #{inspect(reason)}"
    end
  end

  step "the JSON response should contain a {string} field with value {string}",
       %{args: [field_name, expected_value]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    case Jason.decode(response.body) do
      {:ok, json} ->
        actual_value = Map.get(json, field_name)

        if actual_value == expected_value do
          context
        else
          raise "Expected JSON field '#{field_name}' to be '#{expected_value}', got '#{actual_value}'"
        end

      {:error, reason} ->
        raise "Response is not valid JSON: #{inspect(reason)}"
    end
  end

  step "the JSON response should be an array with {int} items",
       %{args: [expected_count]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    case Jason.decode(response.body) do
      {:ok, json} when is_list(json) ->
        actual_count = length(json)

        if actual_count == expected_count do
          context
        else
          raise "Expected JSON array to have #{expected_count} items, got #{actual_count}"
        end

      {:ok, _json} ->
        raise "Expected JSON response to be an array"

      {:error, reason} ->
        raise "Response is not valid JSON: #{inspect(reason)}"
    end
  end

  step "the JSON response should contain an array field {string} with {int} items",
       %{args: [field_name, expected_count]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    case Jason.decode(response.body) do
      {:ok, json} ->
        array = Map.get(json, field_name)

        unless is_list(array) do
          raise "Expected JSON field '#{field_name}' to be an array"
        end

        actual_count = length(array)

        if actual_count == expected_count do
          context
        else
          raise "Expected JSON array field '#{field_name}' to have #{expected_count} items, got #{actual_count}"
        end

      {:error, reason} ->
        raise "Response is not valid JSON: #{inspect(reason)}"
    end
  end
end

