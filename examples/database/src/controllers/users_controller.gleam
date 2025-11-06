//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

import dream/core/http/transaction.{
  type PathParam, type Request, type Response, get_param,
}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import context.{type DatabaseContext}
import models/user
import services.{type Services}
import pog

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection

  user.list(db)
  |> response.many_rows(user.encode_list)
}

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> response.bad_request()
    Ok(param) -> show_with_param(param, services)
  }
}

fn show_with_param(param: PathParam, services: Services) -> Response {
  case param.as_int {
    Error(_) -> response.bad_request()
    Ok(id) -> show_user(id, services)
  }
}

fn show_user(id: Int, services: Services) -> Response {
  let db = services.database.connection
  user.get(db, id)
  |> response.one_row(user.encode)
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> create_with_data(data, db)
  }
}

fn create_with_data(data: #(String, String), db: pog.Connection) -> Response {
  let #(name, email) = data
  user.create(db, name, email)
  |> response.one_row(user.encode_create)
}

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> response.bad_request()
    Ok(param) -> update_with_param(param, request, services)
  }
}

fn update_with_param(
  param: PathParam,
  request: Request,
  services: Services,
) -> Response {
  case param.as_int {
    Error(_) -> response.bad_request()
    Ok(id) -> update_user(id, request, services)
  }
}

fn update_user(id: Int, request: Request, services: Services) -> Response {
  let db = services.database.connection
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> update_user_with_data(id, data, db)
  }
}

fn update_user_with_data(
  id: Int,
  data: #(String, String),
  db: pog.Connection,
) -> Response {
  let #(name, email) = data
  user.update(db, id, name, email)
  |> response.one_row(user.encode_update)
}

/// Delete a user
pub fn delete(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> response.bad_request()
    Ok(param) -> delete_with_param(param, services)
  }
}

fn delete_with_param(param: PathParam, services: Services) -> Response {
  case param.as_int {
    Error(_) -> response.bad_request()
    Ok(id) -> delete_user(id, services)
  }
}

fn delete_user(id: Int, services: Services) -> Response {
  let db = services.database.connection
  user.delete(db, id)
  |> response.success
}
