//// Users Controller - HTTP handlers
////
//// Handles HTTP concerns: parsing, error mapping, response building.
//// Delegates to models for data, views for formatting.

import context.{type Context}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream_helpers/http.{json_response}
import dream_helpers/statuses.{
  created_status, internal_server_error_status, not_found_status, ok_status,
}
import models/user/user
import services.{type Services}
import types/errors.{DatabaseError, NotFound}
import views/user_view

/// List all users
pub fn index(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  case user.list(services.db) {
    Ok(users) -> json_response(ok_status(), user_view.list_to_json(users))
    Error(DatabaseError) ->
      json_response(
        internal_server_error_status(),
        "{\"error\": \"Internal error\"}",
      )
    Error(_) ->
      json_response(
        internal_server_error_status(),
        "{\"error\": \"Internal error\"}",
      )
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
    Ok(user_data) -> json_response(ok_status(), user_view.to_json(user_data))
    Error(NotFound) ->
      json_response(not_found_status(), "{\"error\": \"User not found\"}")
    Error(_) ->
      json_response(
        internal_server_error_status(),
        "{\"error\": \"Internal error\"}",
      )
  }
}

