//// Requests to the apps, sent through their routers as the server sends
//// them, and the text of a response.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Method, type Request, Http, Http1, Request}
import dream/http/response.{type Response, Text}
import dream/router.{type Router}
import gleam/option

/// Sends `method path` with `body` through `app_router`, with `services`.
pub fn send(
  app_router: Router(context.EmptyContext, services),
  services: services,
  method: Method,
  path: String,
  body: String,
) -> Response {
  dream.route_request(
    app_router,
    request(method, path, body),
    EmptyContext,
    services,
  )
}

/// The body of a response as text: an empty text for a body that is not
/// text.
pub fn body_text(response: Response) -> String {
  case response.body {
    Text(text) -> text
    _ -> ""
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
    content_type: option.Some("application/json"),
    content_length: option.None,
  )
}
