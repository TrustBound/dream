//// The answers that Dream gives itself, with no controller: the request
//// matches no route, or its body is too large or cannot be read. Each one is
//// a short plain-text body. The server and `dream.route_request` both take
//// them from here, so they give the same answer.

import dream/http/header.{Header}
import dream/http/request.{type Method, type Request, method_to_string}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type Router, allowed_methods}
import gleam/list
import gleam/option
import gleam/string

/// A response with a plain-text body
pub fn plain_text(status: Int, text: String) -> Response {
  Response(
    status: status,
    body: Text(text),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// The answer to a request that no route matches. When a route matches the
/// path with another method, it is `405 Method Not Allowed` with the methods
/// of the path in the `Allow` header (RFC 9110, section 15.5.6). When no
/// route matches the path, it is `404 Not Found`.
pub fn no_route(
  router: Router(context, services),
  request: Request,
) -> Response {
  case allowed_methods(router, request) {
    [] -> plain_text(404, "Route not found")
    methods -> method_not_allowed(methods)
  }
}

fn method_not_allowed(methods: List(Method)) -> Response {
  let answer = plain_text(405, "Method not allowed")
  let allow =
    methods
    |> list.map(method_to_string)
    // Other("GET") and Get have the same name
    |> list.unique
    |> string.join(", ")
  Response(
    ..answer,
    headers: list.append(answer.headers, [Header("Allow", allow)]),
  )
}
