//// Users Controller - HTTP handlers
////
//// Handles HTTP concerns: parsing, error mapping, response building.
//// Delegates to models for data, views for formatting.

import context.{type Context}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, json_response}
import dream/http/status
import models/user/user
import services.{type Services}
import types/errors.{type DataError, DatabaseError, NotFound}
import views/user_view

/// List all users
pub fn index(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  case user.list(services.db) {
    Ok(users) -> json_response(status.ok, user_view.list_to_json(users))
    Error(DatabaseError) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

/// Show single user
pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case user.get(services.db, id) {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(NotFound) ->
      json_response(status.not_found, "{\"error\": \"User not found\"}")
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

