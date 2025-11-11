//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

import context.{type DatabaseContext}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/core/http/validation.{validate_json}
import models/user
import services.{type Services}
import views/errors
import views/user_view

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  user.list(db)
  |> user_view.respond_list()
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
  user.get(db, id)
  |> user_view.respond()
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case validate_json(request.body, user.decoder()) {
    Error(_) -> errors.bad_request("Invalid user data")
    Ok(data) -> create_with_data(services, data)
  }
}

fn create_with_data(services: Services, data: #(String, String)) -> Response {
  let db = services.database.connection
  let #(name, email) = data
  user.create(db, name, email)
  |> user_view.respond_created()
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
    Error(_) -> errors.bad_request("Invalid user data")
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
  user.update(db, id, name, email)
  |> user_view.respond_updated()
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
  user.delete(db, id)
  |> user_view.respond_deleted()
}
