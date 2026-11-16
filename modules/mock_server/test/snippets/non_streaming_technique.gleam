//// README: Non-Streaming Technique

import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/json

pub fn get(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let body =
    json.object([
      #("method", json.string("GET")),
      #("url", json.string(request.path)),
    ])
    |> json.to_string

  json_response(status.ok, body)
}
