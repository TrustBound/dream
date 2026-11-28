//// Requests to the shop, sent through its router as the server sends them,
//// and a short text of each answer for the outputs of the guide.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/header.{get_header}
import dream/http/request.{type Method, type Request, Http, Http1, Request}
import dream/http/response.{type Response, Text}
import gleam/int
import gleam/option
import router
import services.{type Services}

/// Sends `method path` with `body` through the routes of the shop
pub fn send(
  services: Services,
  method: Method,
  path: String,
  body: String,
) -> Response {
  dream.route_request(
    router.create_router(),
    request(method, path, body),
    EmptyContext,
    services,
  )
}

/// One request and its answer, as the outputs of the guide show them:
/// the time and the request, the status with the `x-cache` header, and
/// the body
pub fn describe_exchange(
  second: Int,
  method: String,
  path: String,
  response: Response,
) -> String {
  "after "
  <> int.to_string(second)
  <> " s: "
  <> method
  <> " "
  <> path
  <> "\n  "
  <> int.to_string(response.status)
  <> cache_header(response)
  <> body_text(response)
  <> "\n"
}

fn cache_header(response: Response) -> String {
  case get_header(response.headers, "x-cache") {
    option.Some(value) -> ", x-cache: " <> value <> "\n  "
    option.None -> "\n  "
  }
}

pub fn body_text(response: Response) -> String {
  case response.body {
    Text("") -> "(no body)"
    Text(text) -> text
    _ -> "(not text)"
  }
}

fn request(method: Method, path: String, body: String) -> Request {
  Request(
    method:,
    protocol: Http,
    version: Http1,
    path:,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(body),
    headers: [],
    cookies: [],
    content_type: option.Some("text/plain"),
    content_length: option.None,
  )
}
