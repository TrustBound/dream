defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias HTTPoison, as: HTTP

  @base_url "http://localhost:3004"

  step "the server is running on port {int}", %{args: [_port]} = context do
    # Assume server is started externally (via Makefile or manually)
    context
  end

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    response =
      case String.upcase(method) do
        "GET" -> HTTP.get(url, headers, timeout: 30_000, recv_timeout: 30_000)
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
      {:error, reason} -> raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  step "the response status should be {int}", %{args: [expected_status]} = context do
    actual_status = context.response.status_code

    if actual_status == expected_status do
      context
    else
      raise "Expected status #{expected_status}, got #{actual_status}. Body: #{String.slice(context.response.body, 0, 200)}"
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

  step "the response should contain {string}", %{args: [expected_content]} = context do
    actual_body = context.response.body

    case String.contains?(actual_body, expected_content) do
      true -> context
      false ->
        raise "Response body does not contain expected content: '#{expected_content}'. Actual body: #{String.slice(actual_body, 0, 200)}..."
    end
  end

  step "the response should have at least {int} lines", %{args: [min_lines]} = context do
    actual_body = context.response.body
    lines = String.split(actual_body, "\n") |> Enum.filter(&(&1 != ""))

    if length(lines) >= min_lines do
      context
    else
      raise "Expected at least #{min_lines} lines, got #{length(lines)}. Body: #{String.slice(actual_body, 0, 200)}"
    end
  end

  step "the response should contain valid JSON", %{} = context do
    actual_body = context.response.body
    lines = String.split(actual_body, "\n") |> Enum.filter(&(&1 != ""))

    # Try to parse each line as JSON
    Enum.each(lines, fn line ->
      case Jason.decode(line) do
        {:ok, _} -> :ok
        {:error, reason} ->
          raise "Line is not valid JSON: #{line}. Error: #{inspect(reason)}"
      end
    end)

    context
  end

  step "the response body should not be empty", %{} = context do
    actual_body = context.response.body

    if byte_size(actual_body) > 0 do
      context
    else
      raise "Response body is empty"
    end
  end

  step "the response body should be empty", %{} = context do
    actual_body = context.response.body

    if byte_size(actual_body) == 0 do
      context
    else
      raise "Response body is not empty, has #{byte_size(actual_body)} bytes"
    end
  end

  step "the response should not contain {string}", %{args: [unexpected_content]} = context do
    actual_body = context.response.body

    case String.contains?(actual_body, unexpected_content) do
      false -> context
      true ->
        raise "Response body should not contain '#{unexpected_content}', but it does. Body: #{String.slice(actual_body, 0, 200)}..."
    end
  end

  step "the response should have exactly {int} lines", %{args: [expected_lines]} = context do
    actual_body = context.response.body
    lines = String.split(actual_body, "\n") |> Enum.filter(&(&1 != ""))

    if length(lines) == expected_lines do
      context
    else
      raise "Expected exactly #{expected_lines} lines, got #{length(lines)}. Body: #{String.slice(actual_body, 0, 200)}"
    end
  end

  step "the response header {string} should contain {string}", %{args: [header_name, expected_value]} = context do
    headers = context.response.headers
    header_value =
      Enum.find_value(headers, fn {name, value} ->
        if String.downcase(name) == String.downcase(header_name), do: value
      end)

    case header_value do
      nil ->
        raise "Header '#{header_name}' not found. Available headers: #{inspect(Enum.map(headers, fn {name, _} -> name end))}"
      value ->
        if String.contains?(value, expected_value) do
          context
        else
          raise "Header '#{header_name}' value '#{value}' does not contain '#{expected_value}'"
        end
    end
  end

  step "the response body size should be at least {int} bytes", %{args: [min_bytes]} = context do
    actual_size = byte_size(context.response.body)

    if actual_size >= min_bytes do
      context
    else
      raise "Expected at least #{min_bytes} bytes, got #{actual_size} bytes"
    end
  end

  step "I send {int} concurrent GET requests to {string}", %{args: [count, path]} = context do
    url = "#{@base_url}#{path}"
    headers = []

    # Send concurrent requests
    tasks =
      Enum.map(1..count, fn _ ->
        Task.async(fn ->
          HTTP.get(url, headers, timeout: 30_000, recv_timeout: 30_000)
        end)
      end)

    # Wait for all responses
    responses =
      tasks
      |> Enum.map(&Task.await(&1, 35_000))
      |> Enum.map(fn
        {:ok, http_response} -> http_response
        {:error, reason} -> raise "HTTP request failed: #{inspect(reason)}"
      end)

    Map.put(context, :responses, responses)
  end

  step "all {int} responses should have status {int}", %{args: [count, expected_status]} = context do
    responses = context.responses

    if length(responses) != count do
      raise "Expected #{count} responses, got #{length(responses)}"
    end

    Enum.each(responses, fn response ->
      if response.status_code != expected_status do
        raise "Expected all responses to have status #{expected_status}, but got #{response.status_code}"
      end
    end)

    context
  end

  step "all {int} responses should have exactly {int} lines", %{args: [count, expected_lines]} = context do
    responses = context.responses

    if length(responses) != count do
      raise "Expected #{count} responses, got #{length(responses)}"
    end

    Enum.each(responses, fn response ->
      lines = String.split(response.body, "\n") |> Enum.filter(&(&1 != ""))
      if length(lines) != expected_lines do
        raise "Expected all responses to have exactly #{expected_lines} lines, but got #{length(lines)}"
      end
    end)

    context
  end

  step "I concurrently request {string} and {string}", %{args: [path1, path2]} = context do
    url1 = "#{@base_url}#{path1}"
    url2 = "#{@base_url}#{path2}"
    headers = []

    # Send concurrent requests
    task1 = Task.async(fn -> HTTP.get(url1, headers, timeout: 30_000, recv_timeout: 30_000) end)
    task2 = Task.async(fn -> HTTP.get(url2, headers, timeout: 30_000, recv_timeout: 30_000) end)

    # Wait for both responses
    response1 =
      case Task.await(task1, 35_000) do
        {:ok, http_response} -> http_response
        {:error, reason} -> raise "First request failed: #{inspect(reason)}"
      end

    response2 =
      case Task.await(task2, 35_000) do
        {:ok, http_response} -> http_response
        {:error, reason} -> raise "Second request failed: #{inspect(reason)}"
      end

    context
    |> Map.put(:response1, response1)
    |> Map.put(:response2, response2)
  end

  step "both responses should have status {int}", %{args: [expected_status]} = context do
    if context.response1.status_code != expected_status do
      raise "Expected first response status #{expected_status}, got #{context.response1.status_code}"
    end

    if context.response2.status_code != expected_status do
      raise "Expected second response status #{expected_status}, got #{context.response2.status_code}"
    end

    context
  end

  step "the first response should have exactly {int} lines", %{args: [expected_lines]} = context do
    lines = String.split(context.response1.body, "\n") |> Enum.filter(&(&1 != ""))

    if length(lines) == expected_lines do
      context
    else
      raise "Expected first response to have exactly #{expected_lines} lines, got #{length(lines)}"
    end
  end

  step "the second response should have exactly {int} lines", %{args: [expected_lines]} = context do
    lines = String.split(context.response2.body, "\n") |> Enum.filter(&(&1 != ""))

    if length(lines) == expected_lines do
      context
    else
      raise "Expected second response to have exactly #{expected_lines} lines, got #{length(lines)}"
    end
  end
end
