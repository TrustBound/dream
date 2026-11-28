//// Streaming quick reference: Upload File (Ingress)
////
//// A streaming route and a controller that counts the uploaded bytes, as
//// shown in docs/guides/streaming-quick-reference.md.

import dream/http/request.{type Request, Post, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/bit_array
import gleam/int
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
    Stream(stream) -> {
      let total_bytes = yielder.fold(stream, 0, add_chunk_size)

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes",
      )
    }
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn add_chunk_size(total_bytes: Int, chunk: BitArray) -> Int {
  total_bytes + bit_array.byte_size(chunk)
}
