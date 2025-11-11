//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/core/http/response.{json_response}
import dream/core/http/status
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/core/http/validation.{validate_json}
import models/user
import services.{type Services}
import types/errors
import views/errors as error_responses
import views/user_view

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  case user.list(db) {
    Ok(users) -> json_response(status.ok, user_view.list_to_json(users))
    Error(_) -> error_responses.internal_error()
  }
}

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  let db = services.database.connection
  case user.get(db, id) {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(errors.NotFound) -> error_responses.not_found("User not found")
    Error(_) -> error_responses.internal_error()
  }
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case validate_json(request.body, user.decoder()) {
    Error(_) -> error_responses.bad_request("Invalid user data")
    Ok(data) -> create_with_data(services, data)
  }
}

fn create_with_data(services: Services, data: #(String, String)) -> Response {
  let db = services.database.connection
  let #(name, email) = data
  case user.create(db, name, email) {
    Ok(user_data) -> json_response(status.created, user_view.to_json(user_data))
    Error(_) -> error_responses.internal_error()
  }
}

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  case validate_json(request.body, user.decoder()) {
    Error(_) -> error_responses.bad_request("Invalid user data")
    Ok(data) -> update_with_data(services, id, data)
  }
}

fn update_with_data(
  services: Services,
  id: Int,
  data: #(String, String),
) -> Response {
  let db = services.database.connection
  let #(name, email) = data
  case user.update(db, id, name, email) {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(errors.NotFound) -> error_responses.not_found("User not found")
    Error(_) -> error_responses.internal_error()
  }
}

/// Delete a user
pub fn delete(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  let db = services.database.connection
  case user.delete(db, id) {
    Ok(_) -> json_response(status.ok, "{\"message\": \"User deleted\"}")
    Error(_) -> error_responses.not_found("User not found")
  }
}
