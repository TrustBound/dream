//// api_controller.gleam - Non-streaming API endpoints
////
//// Handles HTTP concerns: parsing, response building.
//// All formatting is delegated to the view layer.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, get_int_param}
import dream/http/response.{type Response, json_response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import dream_mock_server/views/api_view
import gleam/erlang/process
import gleam/string

/// GET /get - Returns JSON with request info
pub fn get(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.get_to_json(request.path))
}

/// POST /post - Echoes request body as JSON
pub fn post(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(
    status.created,
    api_view.post_to_json(request.path, request.body),
  )
}

/// PUT /put - Echoes request body as JSON
pub fn put(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.put_to_json(request.path, request.body))
}

/// DELETE /delete - Returns success response
pub fn delete(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.delete_to_json(request.path))
}

/// GET /status/:code - Returns response with specified status code
pub fn status(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case get_int_param(request, "code") {
    Ok(code) -> json_response(code, api_view.status_to_json(code))
    Error(error_msg) ->
      json_response(status.bad_request, api_view.error_to_json(error_msg))
  }
}

/// GET /json - Returns simple JSON object
pub fn json_endpoint(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.simple_json_to_string())
}

/// GET /text - Returns plain text
pub fn text(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, api_view.text_to_string())
}

/// GET /uuid - Returns a UUID-like string (simple version)
pub fn uuid(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.uuid_to_json())
}

/// GET /large - Returns a very large response body (for memory testing)
pub fn large(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Generate ~1MB of text data
  let chunk = "This is a repeated line to create a large response body.\n"
  let repeated = string.repeat(chunk, 20_000)
  text_response(status.ok, repeated)
}

/// GET /empty - Returns empty response body
pub fn empty(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "")
}

/// GET /slow - Returns response after a long delay
pub fn slow(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Wait 5 seconds before responding
  process.sleep(5000)
  text_response(status.ok, "Slow response")
}
