//// Requests to the links app, sent through its router as the server
//// sends them.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{type Response, Text}
import gleam/option
import links/router
import links/services.{type Services}

/// Sends `GET path` through the routes of the app, with `services`.
pub fn get(services: Services, path: String) -> Response {
  dream.route_request(
    router.create_router(),
    request(path),
    EmptyContext,
    services,
  )
}

/// The status and the body of a response, with an empty body for a body
/// that is not text.
pub fn answer(response: Response) -> #(Int, String) {
  case response.body {
    Text(text) -> #(response.status, text)
    _ -> #(response.status, "")
  }
}

fn request(path: String) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path:,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}
