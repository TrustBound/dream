defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias HTTPoison, as: HTTP

  @base_url "http://localhost:8080"

  step "the server is running on port {int}", %{args: [_port]} = context do
    # Assume server is started externally (via Makefile or manually)
    context
  end

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    response =
      case String.upcase(method) do
        "GET" -> HTTP.get(url, headers, timeout: 15_000, recv_timeout: 15_000)
        "POST" -> HTTP.post(url, "", headers)
        "PUT" -> HTTP.put(url, "", headers)
        "DELETE" -> HTTP.delete(url, headers)
        "PATCH" -> HTTP.patch(url, "", headers)
        "HEAD" -> HTTP.head(url, headers)
        "OPTIONS" -> HTTP.options(url, headers)
        _ -> {:error, "Unsupported HTTP method: #{method}"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
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

  step "the response should contain {string}", %{args: [expected_content]} = context do
    actual_body = context.response.body

    case String.contains?(actual_body, expected_content) do
      true ->
        context

      false ->
        raise "Response body does not contain expected content: '#{expected_content}'. Actual body: #{String.slice(actual_body, 0, 200)}..."
    end
  end
end


