//// Streaming guide: Basic Streaming Response
////
//// A controller that streams 1000 lines, as shown in docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response}
import dream/http/status
import gleam/int
import gleam/yielder

pub fn download(_request: Request, _context, _services) -> Response {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(number_to_line)

  stream_response(status.ok, stream, "text/plain")
}

fn number_to_line(number: Int) -> BitArray {
  let line = "Line " <> int.to_string(number) <> "\n"
  <<line:utf8>>
}
