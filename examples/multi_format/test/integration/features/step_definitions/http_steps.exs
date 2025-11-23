defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias HTTPoison, as: HTTP
  alias Jason
  alias Postgrex

  @base_url "http://localhost:3000"

  step "the database is clean", context do
    # Connect to the test database (support both local docker and CI postgres)
    port = String.to_integer(System.get_env("POSTGRES_PORT", "5435"))

    {:ok, pid} = Postgrex.start_link(
      username: "postgres",
      password: "postgres",
      database: "dream_example_multi_format_db",
      hostname: "localhost",
      port: port
    )

    # Truncate and reseed products table
    {:ok, _} = Postgrex.query(pid, "TRUNCATE products RESTART IDENTITY CASCADE", [])

    # Insert seed data (same as migration)
    seed_sql = """
    INSERT INTO products (name, price, stock, created_at) VALUES
      ('Laptop', 999.99, 10, NOW()),
      ('Mouse', 29.99, 50, NOW()),
      ('Keyboard', 79.99, 30, NOW()),
      ('Monitor', 299.99, 15, NOW()),
      ('Webcam', 89.99, 25, NOW());
    """
    {:ok, _} = Postgrex.query(pid, seed_sql, [])

    # Stop connection
    GenServer.stop(pid)

    context
  end

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

  step "the response status should be {int}", %{args: [expected_status]} = context do
    actual_status = context.response.status_code

    if actual_status == expected_status do
      context
    else
      raise "Expected status #{expected_status}, got #{actual_status}. Body: #{context.response.body}"
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

  step "the response should be valid JSON", context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, _json} -> context
      {:error, reason} -> raise "Response is not valid JSON: #{reason}. Body: #{body}"
    end
  end

  step "the JSON response should be an array", context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} when is_list(json) -> context
      {:ok, _json} -> raise "Response is not a JSON array"
      {:error, reason} -> raise "Response is not valid JSON: #{reason}. Body: #{body}"
    end
  end

  step "the JSON response should be an object", context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} when is_map(json) -> context
      {:ok, _json} -> raise "Response is not a JSON object"
      {:error, reason} -> raise "Response is not valid JSON: #{reason}. Body: #{body}"
    end
  end

  step "the response should contain CSV headers", context do
    body = context.response.body
    lines = String.split(body, "\n") |> Enum.filter(&(&1 != ""))

    if Enum.empty?(lines) do
      raise "Response is empty"
    end

    first_line = List.first(lines)

    # Check if first line contains comma-separated values (basic CSV check)
    if String.contains?(first_line, ",") do
      context
    else
      raise "Response does not appear to be CSV format. First line: #{first_line}"
    end
  end

  step "the JSON response should contain field {string}", %{args: [field_name]} = context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} when is_map(json) ->
        if Map.has_key?(json, field_name) do
          context
        else
          raise "JSON response does not contain field '#{field_name}'. Available fields: #{Map.keys(json) |> Enum.join(", ")}"
        end

      {:ok, _json} ->
        raise "Response is not a JSON object"

      {:error, reason} ->
        raise "Response is not valid JSON: #{reason}. Body: #{body}"
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
end
