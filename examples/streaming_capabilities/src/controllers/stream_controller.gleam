import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Bytes, Stream, Text}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import dream_http_client/client
import gleam/bit_array
import gleam/bytes_tree
import gleam/http
import gleam/int
import gleam/yielder
import services.{type Services}

/// Ingress Streaming: Receives a stream and "saves" it (logs size)
pub fn upload(
  request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  case request.body {
    Stream(stream) -> {
      // Consume the stream "saving" it
      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    }
    Text(_) | Bytes(_) ->
      text_response(status.bad_request, "Expected streaming request body")
  }
}

/// Egress Streaming: Generates data on the fly and streams it out
pub fn download(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  // Generate a stream of numbers
  let stream = yielder.range(1, 1000) |> yielder.map(create_line)

  stream_response(status.ok, stream, "text/plain")
}

/// Bi-Directional Echo: Simply echoes the request stream back
/// Middleware will transform it on the way in AND out
pub fn echo_transform(
  request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  case request.body {
    Stream(stream) -> {
      // Just echo the stream back!
      // The middleware does the heavy lifting (uppercase -> replace space)
      stream_response(status.ok, stream, "text/plain")
    }
    Text(_) | Bytes(_) ->
      text_response(status.bad_request, "Expected streaming request body")
  }
}

/// Proxy Streaming: Streams from mock server
/// Demonstrates using dream_http_client to proxy a stream
pub fn proxy(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  // Use dream_http_client to stream from mock server
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/stream/fast")
    |> client.timeout(15_000)

  // Stream from mock server. A failure ends the stream with an error line,
  // because the 200 status is already sent when the failure occurs.
  let stream = client.stream_yielder(req) |> yielder.map(chunk_or_failure_line)

  stream_response(status.ok, stream, "text/plain")
}

fn accumulate_chunk_size(acc: Int, chunk: BitArray) -> Int {
  let size = bit_array.byte_size(chunk)
  // Simulate saving to disk
  acc + size
}

fn create_line(n: Int) -> BitArray {
  let line = "Line " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

fn chunk_or_failure_line(
  result: Result(bytes_tree.BytesTree, client.StreamFailure),
) -> BitArray {
  case result {
    Ok(chunk) -> bytes_tree.to_bit_array(chunk)
    Error(failure) ->
      bit_array.from_string(
        "Proxy stream failed: "
        <> client.stream_failure_to_string(failure)
        <> "\n",
      )
  }
}
