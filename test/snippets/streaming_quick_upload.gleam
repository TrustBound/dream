//// Streaming quick reference: Upload File (Ingress)
////
//// A streaming route and a controller that counts the uploaded bytes, as
//// shown in docs/guides/streaming-quick-reference.md.

import dream/http/request.{type BodyReadError, type Request, Post, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/result
import gleam/yielder

// Router
pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload_file,
    middleware: [],
  )
}

// Controller
pub fn upload_file(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      yielder.try_fold(stream, 0, add_chunk_size)
      |> respond_with_total
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn respond_with_total(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes",
      )
    // The connection broke before the client sent the whole body
    Error(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}

fn add_chunk_size(
  total_bytes: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  total_bytes + bit_array.byte_size(chunk)
}
