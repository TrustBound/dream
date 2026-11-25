//// Requests to the notes app, sent through its router as the server sends
//// them, and the text of a response.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Method, type Request, Http, Http1, Request}
import dream/http/response.{type Response, Text}
import gleam/option
import notes/router
import notes/services.{type Services}

/// Sends `method path?query` with `body` through the routes of the app,
/// with `services`
pub fn send(
  services: Services,
  method: Method,
  path: String,
  query: String,
  body: String,
) -> Response {
  dream.route_request(
    router.create_router(),
    request(method, path, query, body),
    EmptyContext,
    services,
  )
}

/// The status and the text body of a response. A body that is not text
/// gives an empty text.
pub fn answer(response: Response) -> #(Int, String) {
  case response.body {
    Text(text) -> #(response.status, text)
    _ -> #(response.status, "")
  }
}

fn request(
  method: Method,
  path: String,
  query: String,
  body: String,
) -> Request {
  Request(
    method:,
    protocol: Http,
    version: Http1,
    path:,
    query:,
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(body),
    headers: [],
    cookies: [],
    content_type: option.Some("application/json"),
    content_length: option.None,
  )
}
