//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import examples/database/context.{type DatabaseContext}
import examples/database/models/user
import examples/database/services.{type Services}
import gleam/int
import gleam/result

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
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)

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
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email)
      |> response.one_row(user.encode_create)
    }
  }
}

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)

  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.update(db, id, name, email)
      |> response.one_row(user.encode_update)
    }
  }
}

/// Delete a user
pub fn delete(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)

  user.delete(db, id)
  |> response.success
}
