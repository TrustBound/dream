//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

import context.{type DatabaseContext}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream_helpers/validators.{validate_or_respond}
import models/user
import services.{type Services}
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
  let db = services.database.connection
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email)
      |> user_view.respond_created()
    }
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

  let db = services.database.connection
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.update(db, id, name, email)
      |> user_view.respond_updated()
    }
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
  user.delete(db, id)
  |> user_view.respond_deleted()
}
