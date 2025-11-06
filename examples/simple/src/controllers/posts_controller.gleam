//// posts_controller.gleam
////
//// Controller for simple example routes.
//// Follows Rails controller naming conventions.

import dream/core/context.{type AppContext}
import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, ok_status,
}
import dream/core/http/transaction.{
  type PathParam, type Request, type Response, get_param, text_response,
}
import dream/core/router.{type EmptyServices}
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import gleam/http

/// Index action - displays hello world
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok_status(), "Hello, World!")
}

/// Show action - demonstrates path parameters and makes HTTPS request
pub fn show(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> bad_request_response()
    Ok(user_param) -> show_with_user_param(request, user_param)
  }
}

fn show_with_user_param(request: Request, user_param: PathParam) -> Response {
  case get_param(request, "post_id") {
    Error(_) -> bad_request_response()
    Ok(post_param) -> show_with_params(user_param, post_param)
  }
}

fn show_with_params(user_param: PathParam, post_param: PathParam) -> Response {
  // Make a non-streaming HTTPS request to jsonplaceholder.typicode.com
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("jsonplaceholder.typicode.com")
    |> client.path("/posts")
    |> client.add_header("User-Agent", "Dream-Simple-Example")

  case fetch_module.request(req) {
    Ok(body) ->
      text_response(
        ok_status(),
        "User: "
          <> user_param.value
          <> ", Post: "
          <> post_param.value
          <> "\n\nHTTPS Response:\n\n"
          <> body,
      )
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}

fn bad_request_response() -> Response {
  text_response(bad_request_status(), "Bad request")
}
