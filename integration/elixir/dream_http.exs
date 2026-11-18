defmodule DreamHttp do
  @moduledoc """
  Sends the integration tests' requests with dream_http_client, through the
  Gleam bridge in `integration/bridge`.

  It has the same functions and results as HTTPoison, so the step
  definitions keep their assertions. Two environment variables pick the run:

  - `DREAM_TEST_PROTOCOL`: `http1` (the default) or `http2`. With `http2` the
    client speaks only HTTP/2, so every answer proves the server used HTTP/2.
  - `DREAM_TEST_CA_FILE`: the certificate authority to trust. When it is set,
    requests go over HTTPS: `http://` in a URL becomes `https://`.
  """

  @bridge Path.expand("../bridge", __DIR__)

  def setup do
    @bridge
    |> Path.join("build/dev/erlang/*/ebin")
    |> Path.wildcard()
    |> Enum.each(&Code.prepend_path/1)

    {:ok, _} = Application.ensure_all_started(:dream_http_client)
    :ok
  end

  def protocol, do: System.get_env("DREAM_TEST_PROTOCOL", "http1")

  def get(url, headers \\ [], options \\ []) do
    case Keyword.get(options, :stream_to) do
      nil -> request("GET", url, "", headers)
      receiver -> stream("GET", url, headers, receiver)
    end
  end
  def head(url, headers \\ [], _options \\ []), do: request("HEAD", url, "", headers)
  def options(url, headers \\ [], _options \\ []), do: request("OPTIONS", url, "", headers)
  def delete(url, headers \\ [], _options \\ []), do: request("DELETE", url, "", headers)
  def post(url, body, headers \\ [], _options \\ []), do: request("POST", url, body, headers)
  def put(url, body, headers \\ [], _options \\ []), do: request("PUT", url, body, headers)
  def patch(url, body, headers \\ [], _options \\ []), do: request("PATCH", url, body, headers)

  def request(method, url, body, headers) do
    certificate_authority = System.get_env("DREAM_TEST_CA_FILE", "")

    url =
      case certificate_authority do
        "" -> url
        _ -> String.replace_prefix(url, "http://", "https://")
      end

    headers = Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)

    case :integration_bridge.request(
           method,
           url,
           headers,
           IO.iodata_to_binary(body),
           protocol(),
           certificate_authority
         ) do
      {:ok, {status, response_headers, response_body}} ->
        {:ok,
         %HTTPoison.Response{
           status_code: status,
           headers: response_headers,
           body: response_body,
           request_url: url
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Starts a streaming request, like HTTPoison with `stream_to:`. The receiver
  gets `%HTTPoison.AsyncStatus{}`, `%HTTPoison.AsyncHeaders{}`,
  `%HTTPoison.AsyncChunk{}` and `%HTTPoison.AsyncEnd{}` messages.
  """
  def stream(method, url, headers, receiver) do
    {url, certificate_authority} = target(url)
    reference = make_ref()
    relay = spawn(fn -> relay(reference, receiver) end)
    headers = Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)

    case :integration_bridge.stream(
           method,
           url,
           headers,
           protocol(),
           certificate_authority,
           relay,
           reference
         ) do
      {:ok, nil} -> {:ok, %HTTPoison.AsyncResponse{id: reference}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp relay(reference, receiver) do
    receive do
      {:dream_stream_status, ^reference, status} ->
        send(receiver, %HTTPoison.AsyncStatus{id: reference, code: status})
        relay(reference, receiver)

      {:dream_stream_headers, ^reference, headers} ->
        send(receiver, %HTTPoison.AsyncHeaders{id: reference, headers: headers})
        relay(reference, receiver)

      {:dream_stream_chunk, ^reference, data} ->
        send(receiver, %HTTPoison.AsyncChunk{id: reference, chunk: data})
        relay(reference, receiver)

      {:dream_stream_end, ^reference} ->
        send(receiver, %HTTPoison.AsyncEnd{id: reference})

      {:dream_stream_error, ^reference, reason} ->
        send(receiver, %HTTPoison.Error{id: reference, reason: reason})
    end
  end

  defp target(url) do
    certificate_authority = System.get_env("DREAM_TEST_CA_FILE", "")

    case certificate_authority do
      "" -> {url, ""}
      _ -> {String.replace_prefix(url, "http://", "https://"), certificate_authority}
    end
  end
end
