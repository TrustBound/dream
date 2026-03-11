defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias HTTPoison, as: HTTP

  @base_url "http://localhost:8081"

  step "the server is running on port {int}", %{args: [_port]} = context do
    context
  end

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    response =
      case String.upcase(method) do
        "GET" -> HTTP.get(url, headers, timeout: 15_000, recv_timeout: 15_000)
        "POST" -> HTTP.post(url, "", headers)
        _ -> {:error, "Unsupported HTTP method: #{method}"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  step "the response status should be {int}", %{args: [expected_status]} = context do
    actual_status = context.response.status_code

    if actual_status == expected_status do
      context
    else
      raise "Expected status #{expected_status}, got #{actual_status}. Body: #{context.response.body}"
    end
  end

  step "the response header {string} should contain {string}",
       %{args: [header_name, expected_value]} = context do
    headers = context.response.headers
    header_values = for {k, v} <- headers, String.downcase(k) == String.downcase(header_name), do: v

    case header_values do
      [] ->
        raise "Header '#{header_name}' not found in response. Headers: #{inspect(headers)}"

      values ->
        combined = Enum.join(values, ", ")
        if String.contains?(combined, expected_value) do
          context
        else
          raise "Header '#{header_name}' value '#{combined}' does not contain '#{expected_value}'"
        end
    end
  end
end
