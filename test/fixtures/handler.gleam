//// Test handler fixtures for router tests.

import dream/context
import dream/http/header.{Header}
import dream/http/params.{require_int}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type EmptyServices}
import gleam/int
import gleam/option

/// A generic test handler that returns a 200 response with "test" body.
pub fn test_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("test"),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// A handler that returns "literal" - used for testing literal route matches.
pub fn literal_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("literal"),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// A handler that returns "param" - used for testing parameter route matches.
pub fn param_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("param"),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// A handler that extracts :id param and returns it in the body.
/// Returns 400 if param is missing or invalid.
pub fn id_param_handler(
  request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  case require_int(request, "id") {
    Ok(id) ->
      Response(
        status: 200,
        body: Text("id: " <> int.to_string(id)),
        headers: [],
        cookies: [],
        content_type: option.None,
      )
    Error(_) ->
      Response(
        status: 400,
        body: Text("Missing id parameter"),
        headers: [],
        cookies: [],
        content_type: option.None,
      )
  }
}

/// A handler that extracts :user_id and :post_id params.
/// Returns 400 if either param is missing or invalid.
pub fn multi_param_handler(
  request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  case require_int(request, "user_id"), require_int(request, "post_id") {
    Error(_), _ ->
      Response(
        status: 400,
        body: Text("Missing user_id parameter"),
        headers: [],
        cookies: [],
        content_type: option.None,
      )
    Ok(_), Error(_) ->
      Response(
        status: 400,
        body: Text("Missing post_id parameter"),
        headers: [],
        cookies: [],
        content_type: option.None,
      )
    Ok(user_id), Ok(post_id) ->
      Response(
        status: 200,
        body: Text(
          "user: "
          <> int.to_string(user_id)
          <> ", post: "
          <> int.to_string(post_id),
        ),
        headers: [],
        cookies: [],
        content_type: option.None,
      )
  }
}
