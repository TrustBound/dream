import dream/context.{type AppContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/option.{None, Some}
import gleam/yielder
import services.{type Services}

/// Ingress Streaming: Receives a stream and "saves" it (logs size)
pub fn upload(req: Request, _ctx: AppContext, _svc: Services) -> Response {
  case req.stream {
    Some(stream) -> {
      // Consume the stream "saving" it
      let total_bytes =
        stream
        |> yielder.fold(0, fn(acc, chunk) {
          let size = bit_array.byte_size(chunk)
          // Simulate saving to disk
          acc + size
        })

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    }
    None -> text_response(status.bad_request, "Expected streaming request body")
  }
}

/// Egress Streaming: Generates data on the fly and streams it out
pub fn download(_req: Request, _ctx: AppContext, _svc: Services) -> Response {
  // Generate a stream of numbers
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(fn(n) {
      let line = "Line " <> int.to_string(n) <> "\n"
      bit_array.from_string(line)
    })

  stream_response(status.ok, stream, "text/plain")
}

/// Bi-Directional Echo: Simply echoes the request stream back
/// Middleware will transform it on the way in AND out
pub fn echo_transform(
  req: Request,
  _ctx: AppContext,
  _svc: Services,
) -> Response {
  case req.stream {
    Some(stream) -> {
      // Just echo the stream back!
      // The middleware does the heavy lifting (uppercase -> replace space)
      stream_response(status.ok, stream, "text/plain")
    }
    None -> text_response(status.bad_request, "Expected streaming request body")
  }
}

/// Proxy Streaming: Streams from external API
/// (Using httpbin.org as example)
pub fn proxy(_req: Request, _ctx: AppContext, _svc: Services) -> Response {
  // For this example, we'll simulate a proxy response
  // In a real app, you'd use dream_http_client/stream here

  let stream =
    yielder.from_list([
      "Proxying data...\n",
      "From upstream...\n",
      "To client...\n",
    ])
    |> yielder.map(bit_array.from_string)

  stream_response(status.ok, stream, "text/plain")
}
