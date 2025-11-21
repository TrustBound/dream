//// posts_controller.gleam
////
//// Controller for simple example routes.
//// Follows Rails controller naming conventions.

import dream/context.{type AppContext}
import dream/http.{type Request, type Response}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import dream_http_client/client
import dream_http_client/fetch
import gleam/http as http_lib
import gleam/result
import utilities/response_helpers
import views/post_view

/// Index action - displays hello world
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, post_view.format_index())
}

/// Show action - demonstrates path parameters and makes HTTPS request
pub fn show(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  let result = {
    use user_id <- result.try(http.require_string(request, "id"))
    use post_id <- result.try(http.require_string(request, "post_id"))
    Ok(#(user_id, post_id))
  }

  case result {
    Ok(#(user_id, post_id)) -> make_request_and_respond(user_id, post_id)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn make_request_and_respond(user_id: String, post_id: String) -> Response {
  let req =
    client.new
    |> client.method(http_lib.Get)
    |> client.scheme(http_lib.Https)
    |> client.host("jsonplaceholder.typicode.com")
    |> client.path("/posts")
    |> client.add_header("User-Agent", "Dream-Simple-Example")

  case fetch.request(req) {
    Ok(body) ->
      text_response(status.ok, post_view.format_show(user_id, post_id, body))
    Error(error) ->
      text_response(status.internal_server_error, post_view.format_error(error))
  }
}
