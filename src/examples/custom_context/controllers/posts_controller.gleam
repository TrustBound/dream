//// posts_controller.gleam
////
//// Controller for custom context example routes.
//// Follows Rails controller naming conventions.
//// Assumes authentication is handled by middleware.

import dream/core/http/statuses.{internal_server_error_status, ok_status}
import dream/core/http/transaction.{
  type Request, type Response, get_param, text_response,
}
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import examples/custom_context/context.{type AuthContext}
import gleam/http

/// Index action - displays hello world
pub fn index(_request: Request(AuthContext)) -> Response {
  text_response(ok_status(), "Hello, World!")
}

/// Show action - demonstrates path parameters and makes HTTPS request
pub fn show(request: Request(AuthContext)) -> Response {
  let assert Ok(user_id) = get_param(request, "id")
  let assert Ok(post_id) = get_param(request, "post_id")

  // Make a non-streaming HTTPS request to jsonplaceholder.typicode.com
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("jsonplaceholder.typicode.com")
    |> client.path("/posts")
    |> client.add_header("User-Agent", "Dream-Custom-Context-Example")

  case fetch_module.request(req) {
    Ok(body) ->
      text_response(
        ok_status(),
        "User: "
          <> user_id
          <> ", Post: "
          <> post_id
          <> "\n\nHTTPS Response:\n\n"
          <> body,
      )
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}
