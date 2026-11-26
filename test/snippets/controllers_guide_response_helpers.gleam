import dream/http.{
  type Response, bad_request, conflict, forbidden, gateway_timeout,
  internal_server_error, json_response, not_found, service_unavailable,
  unauthorized, unprocessable_content,
}
import dream/http/error.{type Error, GatewayTimeout, ServiceUnavailable}
import gleam/json

pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) -> json_response(bad_request, error_json(msg))
    error.Unauthorized(_msg) ->
      json_response(unauthorized, error_json("Unauthorized"))
    error.Forbidden(_msg) -> json_response(forbidden, error_json("Forbidden"))
    error.NotFound(msg) -> json_response(not_found, error_json(msg))
    error.Conflict(msg) -> json_response(conflict, error_json(msg))
    error.UnprocessableContent(msg) ->
      json_response(unprocessable_content, error_json(msg))
    error.InternalServerError(_msg) ->
      json_response(internal_server_error, error_json("Internal server error"))
    ServiceUnavailable(_msg) ->
      json_response(service_unavailable, error_json("Service unavailable"))
    GatewayTimeout(_msg) ->
      json_response(gateway_timeout, error_json("Timed out"))
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
