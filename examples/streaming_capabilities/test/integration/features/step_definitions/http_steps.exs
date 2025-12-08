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

  step "I send a {word} request to {string} with body {string}",
       %{args: [method, path, body]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "text/plain"}]

    response =
      case String.upcase(method) do
        "POST" -> HTTP.post(url, body, headers)
        "PUT" -> HTTP.put(url, body, headers)
        "PATCH" -> HTTP.patch(url, body, headers)
        _ -> {:error, "HTTP method #{method} not supported with body"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
    end
  end

  step "I send a {word} request to {string} without body",
       %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    response =
      case String.upcase(method) do
        "POST" -> HTTP.post(url, "", headers)
        "PUT" -> HTTP.put(url, "", headers)
        "PATCH" -> HTTP.patch(url, "", headers)
        _ -> {:error, "HTTP method #{method} not supported"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
    end
  end

  step "I send a {word} request to {string} with body containing {int} bytes",
       %{args: [method, path, byte_count]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "text/plain"}]
    # Generate data of specified size
    body = String.duplicate("A", byte_count)

    response =
      case String.upcase(method) do
        "POST" -> HTTP.post(url, body, headers)
        "PUT" -> HTTP.put(url, body, headers)
        "PATCH" -> HTTP.patch(url, body, headers)
        _ -> {:error, "HTTP method #{method} not supported with body"}
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

  step "the response should be {string}", %{args: [expected_body]} = context do
    actual_body = String.trim(context.response.body)

    if actual_body == expected_body do
      context
    else
      raise "Expected response body '#{expected_body}', got '#{actual_body}'"
    end
  end

  step "the response should start with {string}", %{args: [expected_prefix]} = context do
    actual_body = context.response.body

    case String.starts_with?(actual_body, expected_prefix) do
      true -> context
      false ->
        raise "Response body does not start with '#{expected_prefix}'. Actual body: #{String.slice(actual_body, 0, 100)}..."
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





