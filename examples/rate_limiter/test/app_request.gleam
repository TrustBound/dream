//// Requests to the app, sent through its router as the server sends them,
//// and a short text of each answer for the outputs of the guide.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/header.{Header, get_header}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{type Response}
import gleam/int
import gleam/option
import router
import services.{type Services}

/// Sends `GET path` from the client at `address`, through the routes of the
/// app
pub fn get_from(services: Services, path: String, address: String) -> Response {
  dream.route_request(
    router.create_router(),
    request(path, address),
    EmptyContext,
    services,
  )
}

/// One answer, as the outputs of the guide show it: the time, the status
/// and the rate limit headers
pub fn describe_answer(second: Int, response: Response) -> String {
  "after "
  <> int.to_string(second)
  <> " s: "
  <> int.to_string(response.status)
  <> describe_header(response, "X-RateLimit-Remaining", "remaining")
  <> describe_header(response, "Retry-After", "retry after")
  <> "\n"
}

fn describe_header(response: Response, name: String, label: String) -> String {
  case get_header(response.headers, name) {
    option.Some(value) -> ", " <> label <> " " <> value
    option.None -> ""
  }
}

fn request(path: String, address: String) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path:,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.Some(address),
    body: request.Text(""),
    headers: [Header("Accept", "text/plain")],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}
