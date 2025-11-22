defmodule StreamingSteps do
  use Cucumber.StepDefinition

  step "the uploaded bytes count should be {int}", %{args: [expected_bytes]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    # Extract byte count from response like "Uploaded 10000 bytes successfully"
    body = response.body
    regex = ~r/Uploaded (\d+) bytes successfully/

    case Regex.run(regex, body) do
      [_, actual_bytes_str] ->
        actual_bytes = String.to_integer(actual_bytes_str)

        if actual_bytes == expected_bytes do
          context
        else
          raise "Expected uploaded bytes to be #{expected_bytes}, got #{actual_bytes}"
        end

      nil ->
        raise "Could not parse byte count from response: #{body}"
    end
  end

  step "the response should contain exactly {int} lines", %{args: [expected_lines]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    actual_lines = response.body |> String.split("\n") |> Enum.filter(&(&1 != ""))

    if length(actual_lines) == expected_lines do
      context
    else
      raise "Expected response to contain exactly #{expected_lines} lines, got #{length(actual_lines)}"
    end
  end

  step "each line should match pattern {string}", %{args: [pattern]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    lines = response.body |> String.split("\n") |> Enum.filter(&(&1 != ""))
    # Convert Gleam-style regex to Elixir regex (\\d+ becomes \d+)
    elixir_pattern = String.replace(pattern, "\\\\", "\\")
    regex = Regex.compile!(elixir_pattern)

    mismatched_lines =
      Enum.filter(lines, fn line ->
        not Regex.match?(regex, line)
      end)

    if Enum.empty?(mismatched_lines) do
      context
    else
      raise "Lines did not match pattern '#{pattern}': #{inspect(Enum.take(mismatched_lines, 10))}"
    end
  end
end
