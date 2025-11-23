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
    # Use a unique IP per scenario to avoid rate limit interference
    scenario_ip = Map.get(context, :scenario_ip, "127.0.0.1")
    headers = [{"X-Forwarded-For", scenario_ip}]

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

  step "I send a {word} request to {string} from IP {string}", %{args: [method, path, ip]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"X-Forwarded-For", ip}]

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

  step "I send {int} {word} requests to {string}",
       %{args: [count, method, path]} = context do
    url = "#{@base_url}#{path}"
    # Use a unique IP per scenario to avoid rate limit interference
    scenario_ip = Map.get(context, :scenario_ip, "127.0.0.2")
    headers = [{"X-Forwarded-For", scenario_ip}]

    responses =
      Enum.map(1..count, fn _i ->
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
          {:ok, http_response} -> http_response
          {:error, reason} -> raise "HTTP request failed: #{reason}"
        end
      end)

    Map.put(context, :responses, responses)
  end

  step "I send {int} {word} requests to {string} from IP {string}",
       %{args: [count, method, path, ip]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"X-Forwarded-For", ip}]

    responses =
      Enum.map(1..count, fn _i ->
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
          {:ok, http_response} -> http_response
          {:error, reason} -> raise "HTTP request failed: #{reason}"
        end
      end)

    Map.put(context, :responses, responses)
  end

  step "the response status should be {int}", %{args: [expected_status]} = context do
    actual_status = context.response.status_code

    if actual_status == expected_status do
      context
    else
      raise "Expected status #{expected_status}, got #{actual_status}. Body: #{context.response.body}"
    end
  end

  step "at least one response should have status {int}",
       %{args: [expected_status]} = context do
    responses = Map.get(context, :responses, [])

    if Enum.empty?(responses) do
      raise "No responses found in context"
    end

    has_status =
      Enum.any?(responses, fn response ->
        response.status_code == expected_status
      end)

    if has_status do
      context
    else
      statuses = Enum.map(responses, & &1.status_code) |> Enum.join(", ")
      raise "No response had status #{expected_status}. Statuses: #{statuses}"
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

    unless header_value == expected_value do
      raise "Expected header '#{header_name}' to be '#{expected_value}', got '#{header_value}'"
    end

    context
  end

  step "the response header {string} should exist", %{args: [header_name]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    header_exists =
      Enum.any?(response.headers, fn {name, _value} ->
        String.downcase(name) == String.downcase(header_name)
      end)

    unless header_exists do
      raise "Header '#{header_name}' not found in response"
    end

    context
  end

  step "the response header {string} should not exist", %{args: [header_name]} = context do
    response = Map.get(context, :response)

    unless response do
      raise "No response found in context"
    end

    header_exists =
      Enum.any?(response.headers, fn {name, _value} ->
        String.downcase(name) == String.downcase(header_name)
      end)

    if header_exists do
      raise "Header '#{header_name}' should not exist in response"
    end

    context
  end

  step "all responses should have status {int}", %{args: [expected_status]} = context do
    responses = Map.get(context, :responses, [])

    if Enum.empty?(responses) do
      raise "No responses found in context"
    end

    all_match =
      Enum.all?(responses, fn response ->
        response.status_code == expected_status
      end)

    if all_match do
      context
    else
      statuses = Enum.map(responses, & &1.status_code) |> Enum.join(", ")
      raise "Not all responses had status #{expected_status}. Statuses: #{statuses}"
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
end
