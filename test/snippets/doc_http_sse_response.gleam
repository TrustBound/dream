//// Example for the doc of `response.sse_response`.

import dream/http/response.{type Response, sse_response}
import dream/http/status.{ok}
import gleam/yielder

pub fn events() -> Response {
  let stream = yielder.from_list([<<"data: hello\n\n":utf8>>])
  // Headers: Content-Type: text/event-stream, Cache-Control: no-cache,
  // Connection: keep-alive
  sse_response(ok, stream, "text/event-stream")
}
