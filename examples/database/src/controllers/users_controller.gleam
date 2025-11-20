//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int}
import dream/http/error.{type Error, BadRequest}
import dream/http/response.{json_response}
import dream/http/status
import dream/http/validation.{validate_json}
import gleam/result
import models/user
import operations/user_operations
import services.{type Services}
import utilities/response_helpers
import views/user_view

fn parse_user_data(body: String) -> Result(#(String, String), Error) {
  case validate_json(body, user.decoder()) {
    Ok(d) -> Ok(d)
    Error(_) -> Error(BadRequest("Invalid user data"))
  }
}

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    user_operations.list_users(db)
  }

  case result {
    Ok(users) -> json_response(status.ok, user_view.list_to_json(users))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    user_operations.get_user(db, id)
  }

  case result {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use data <- result.try(parse_user_data(request.body))
    let #(name, email) = data
    let db = services.database.connection
    user_operations.create_user(db, name, email)
  }

  case result {
    Ok(user_data) -> json_response(status.created, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    use data <- result.try(parse_user_data(request.body))
    let #(name, email) = data
    let db = services.database.connection
    user_operations.update_user(db, id, name, email)
  }

  case result {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Delete a user
pub fn delete(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    user_operations.delete_user(db, id)
  }

  case result {
    Ok(_) -> json_response(status.ok, "{\"message\": \"User deleted\"}")
    Error(err) -> response_helpers.handle_error(err)
  }
}
