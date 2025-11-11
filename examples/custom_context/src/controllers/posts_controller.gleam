//// posts_controller.gleam
////
//// Controller for custom context example routes.
//// Follows Rails controller naming conventions.
//// Assumes authentication is handled by middleware.

import context.{type AuthContext}
import dream/core/http/response.{text_response}
import dream/core/http/status
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream_http_client/client
import dream_http_client/fetch
import gleam/http
import services.{type Services}
import views/post_view

/// Index action - displays hello world
pub fn index(
  _request: Request,
  _context: AuthContext,
  _services: Services,
) -> Response {
  text_response(status.ok, post_view.format_index())
}

/// Show action - demonstrates path parameters and makes HTTPS request
pub fn show(
  request: Request,
  _context: AuthContext,
  _services: Services,
) -> Response {
  let assert Ok(user_param) = get_param(request, "id")
  let assert Ok(post_param) = get_param(request, "post_id")

  // Make a non-streaming HTTPS request to jsonplaceholder.typicode.com
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("jsonplaceholder.typicode.com")
    |> client.path("/posts")
    |> client.add_header("User-Agent", "Dream-Custom-Context-Example")

  case fetch.request(req) {
    Ok(body) ->
      text_response(
        status.ok,
        post_view.format_show(user_param.value, post_param.value, body),
      )
    Error(error) ->
      text_response(status.internal_server_error, post_view.format_error(error))
  }
}
