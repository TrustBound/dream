//// Requests to the app, sent through its router as the server sends them,
//// and a short text of each answer for the outputs of the guide.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/header.{get_header}
import dream/http/request.{
  type Method, type Request, Get, Http, Http1, Post, Request,
}
import dream/http/response.{type Response, Text}
import gleam/int
import gleam/option
import router
import services.{type Services}

/// `POST /jobs` with `input` as the body, and the text of the answer
pub fn post_job(services: Services, input: String) -> String {
  send(services, Post, "/jobs", input)
  |> describe_exchange("POST /jobs " <> input, _)
}

/// `GET path`, and the text of the answer
pub fn get(services: Services, path: String) -> String {
  send(services, Get, path, "")
  |> describe_exchange("GET " <> path, _)
}

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

/// The request, then the status, the `retry-after` header when there is
/// one, and the body
fn describe_exchange(request: String, response: Response) -> String {
  request
  <> "\n  "
  <> int.to_string(response.status)
  <> retry_after(response)
  <> " "
  <> body_text(response)
}

fn retry_after(response: Response) -> String {
  case get_header(response.headers, "retry-after") {
    option.Some(value) -> " retry-after: " <> value
    option.None -> ""
  }
}

pub fn body_text(response: Response) -> String {
  case response.body {
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
