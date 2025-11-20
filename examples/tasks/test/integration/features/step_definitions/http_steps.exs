defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias HTTPoison, as: HTTP

  @base_url "http://localhost:3000"

  step "the server is running on port {int}", %{args: [_port]} = context do
    # Assume server is started externally (via Makefile or manually)
    context
  end

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    response =
      case String.upcase(method) do
        "GET" -> HTTP.get(url, headers)
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

  step "I send a {word} request to {string} with the following JSON:",
       %{args: [method, path], docstring: json_body} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "application/json"}]

    response =
      case String.upcase(method) do
        "POST" -> HTTP.post(url, json_body, headers)
        "PUT" -> HTTP.put(url, json_body, headers)
        "PATCH" -> HTTP.patch(url, json_body, headers)
        _ -> {:error, "HTTP method #{method} not supported with JSON body"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
    end
  end

  step "I send a {word} request to {string} with form data {string}",
       %{args: [method, path, form_body]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    response =
      case String.upcase(method) do
        "POST" -> HTTP.post(url, form_body, headers)
        "PUT" -> HTTP.put(url, form_body, headers)
        "PATCH" -> HTTP.patch(url, form_body, headers)
        _ -> {:error, "HTTP method #{method} not supported with form data"}
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
      true -> context
      false ->
        raise "Response body does not contain expected content: '#{expected_content}'. Actual body: #{actual_body}"
    end
  end

  step "the response should not contain {string}", %{args: [unexpected_content]} = context do
    actual_body = context.response.body

    case String.contains?(actual_body, unexpected_content) do
      false -> context
      true ->
        raise "Response body should not contain: '#{unexpected_content}'. Actual body: #{actual_body}"
    end
  end

  step "the response header {string} should be {string}",
       %{args: [header_name, expected_value]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    # Find header (case-insensitive)
    header_value =
      Enum.find_value(response.headers, fn {name, value} ->
        if String.downcase(name) == String.downcase(header_name) do
          value
        else
          nil
        end
      end)

    unless header_value do
      raise "Header '#{header_name}' not found in response"
    end

    # For Content-Type, check if it starts with expected value (to handle charset suffix)
    header_matches =
      if header_name == "Content-Type" do
        String.starts_with?(header_value, expected_value)
      else
        header_value == expected_value
      end

    unless header_matches do
      raise "Expected header '#{header_name}' to be '#{expected_value}' (or start with it), got '#{header_value}'"
    end

    context
  end
end
