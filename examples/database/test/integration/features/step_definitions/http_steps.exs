defmodule HttpSteps do
  use Cucumber.StepDefinition

  alias Jason
  alias Postgrex

  @base_url "http://localhost:3002"

  step "the database is clean", context do
    # Connect to the test database (support both local docker and CI postgres)
    port = String.to_integer(System.get_env("POSTGRES_PORT", "5435"))

    {:ok, pid} = Postgrex.start_link(
      username: "postgres",
      password: "postgres",
      database: "dream_example_database_db",
      hostname: "localhost",
      port: port
    )

    # Truncate tables
    {:ok, _} = Postgrex.query(pid, "TRUNCATE users CASCADE", [])

    # Stop connection
    GenServer.stop(pid)

    context
  end

  step "the server is running on port {int}", %{args: [_port]} = context do
    # Assume server is started externally (via Makefile or manually)
    context
  end

  step "I send a {word} request to {string}", %{args: [method, path]} = context do
    # Replace captured ID placeholder if present
    actual_path = String.replace(path, "<captured_id>", Map.get(context, :captured_id, ""))
    url = "#{@base_url}#{actual_path}"
    headers = []

    response =
      case String.upcase(method) do
        "GET" -> HTTPoison.get(url, headers)
        "POST" -> HTTPoison.post(url, "", headers)
        "PUT" -> HTTPoison.put(url, "", headers)
        "DELETE" -> HTTPoison.delete(url, headers)
        "PATCH" -> HTTPoison.patch(url, "", headers)
        "HEAD" -> HTTPoison.head(url, headers)
        "OPTIONS" -> HTTPoison.options(url, headers)
        _ -> {:error, "Unsupported HTTP method: #{method}"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
    end
  end

  step "I send a {word} request to {string} with the following JSON:",
       %{args: [method, path], docstring: json_body} = context do
    # Replace captured ID placeholder if present
    actual_path = String.replace(path, "<captured_id>", Map.get(context, :captured_id, ""))
    url = "#{@base_url}#{actual_path}"
    headers = [{"Content-Type", "application/json"}]

    response =
      case String.upcase(method) do
        "POST" -> HTTPoison.post(url, json_body, headers)
        "PUT" -> HTTPoison.put(url, json_body, headers)
        "PATCH" -> HTTPoison.patch(url, json_body, headers)
        _ -> {:error, "HTTP method #{method} not supported with JSON body"}
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

  step "the response should be valid JSON", context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, _json} -> context
      {:error, reason} -> raise "Response is not valid JSON: #{reason}. Body: #{body}"
    end
  end

  step "the JSON response should contain field {string} with value {string}",
       %{args: [field_name, expected_value]} = context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} ->
        actual_value = Map.get(json, field_name)

        # Convert actual_value to string for comparison
        actual_value_str =
          cond do
            is_integer(actual_value) -> Integer.to_string(actual_value)
            is_binary(actual_value) -> actual_value
            true -> inspect(actual_value)
          end

        if actual_value_str == expected_value do
          context
        else
          raise "Expected JSON field '#{field_name}' to be '#{expected_value}', got '#{actual_value_str}'"
        end

      {:error, reason} ->
        raise "Response is not valid JSON: #{reason}. Body: #{body}"
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

  step "the JSON response should be an array with {int} items",
       %{args: [expected_count]} = context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} when is_list(json) ->
        actual_count = length(json)

        if actual_count == expected_count do
          context
        else
          raise "Expected JSON array with #{expected_count} items, got #{actual_count}"
        end

      {:ok, _json} ->
        raise "Response is not a JSON array"

      {:error, reason} ->
        raise "Response is not valid JSON: #{reason}. Body: #{body}"
    end
  end

  step "I capture the user ID from the response", context do
    body = context.response.body

    case Jason.decode(body) do
      {:ok, json} when is_map(json) ->
        # Try different possible field names for ID
        user_id =
          Map.get(json, "id") ||
            Map.get(json, "user_id") ||
            Map.get(json, :id) ||
            Map.get(json, :user_id)

        if user_id do
          id_string =
            cond do
              is_integer(user_id) -> Integer.to_string(user_id)
              is_binary(user_id) -> user_id
              true -> inspect(user_id)
            end

          Map.put(context, :captured_id, id_string)
        else
          raise "Response does not contain 'id' or 'user_id' field. Available fields: #{Map.keys(json) |> Enum.join(", ")}. Body: #{body}"
        end

      {:ok, _json} ->
        raise "Response is not a JSON object. Body: #{body}"

      {:error, reason} ->
        raise "Response is not valid JSON: #{reason}. Body: #{body}"
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

  step "I send a {word} request to {string} with invalid JSON", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "application/json"}]
    invalid_json = "{\"name\":\"Test\",\"email\":\"invalid"

    response =
      case String.upcase(method) do
        "POST" -> HTTPoison.post(url, invalid_json, headers)
        "PUT" -> HTTPoison.put(url, invalid_json, headers)
        "PATCH" -> HTTPoison.patch(url, invalid_json, headers)
        _ -> {:error, "HTTP method #{method} not supported with JSON body"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
    end
  end

  step "I send a {word} request to {string} with a unique email", %{args: [method, path]} = context do
    url = "#{@base_url}#{path}"
    headers = [{"Content-Type", "application/json"}]
    # Generate unique email using timestamp
    unique_email = "test_#{System.system_time(:millisecond)}@example.com"
    json_body = Jason.encode!(%{"name" => "Test User", "email" => unique_email})

    response =
      case String.upcase(method) do
        "POST" -> HTTPoison.post(url, json_body, headers)
        "PUT" -> HTTPoison.put(url, json_body, headers)
        "PATCH" -> HTTPoison.patch(url, json_body, headers)
        _ -> {:error, "HTTP method #{method} not supported with JSON body"}
      end

    case response do
      {:ok, http_response} -> Map.put(context, :response, http_response)
      {:error, reason} -> raise "HTTP request failed: #{reason}"
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
end
