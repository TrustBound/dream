//// Users Controller
////
//// Demonstrates CRUD operations for users using the model that dream_model generates
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int, require_json}
import dream/http/response.{json_response}
import dream/http/status.{created, ok}
import gleam/dynamic/decode.{type Decoder, field, string, success}
import gleam/result
import operations/user_operations.{
  create_user, delete_user, get_user, list_users, update_user,
}
import services.{type Services}
import utilities/response_helpers.{handle_error}
import views/user_view.{list_to_json, to_json}

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    list_users(db)
  }

  case result {
    Ok(users) -> json_response(ok, list_to_json(users))
    Error(err) -> handle_error(err)
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
    get_user(db, id)
  }

  case result {
    Ok(user_data) -> json_response(ok, to_json(user_data))
    Error(err) -> handle_error(err)
  }
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use #(name, email) <- result.try(require_json(request, user_decoder()))
    let db = services.database.connection
    create_user(db, name, email)
  }

  case result {
    Ok(user_data) -> json_response(created, to_json(user_data))
    Error(err) -> handle_error(err)
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
    use #(name, email) <- result.try(require_json(request, user_decoder()))
    let db = services.database.connection
    update_user(db, id, name, email)
  }

  case result {
    Ok(user_data) -> json_response(ok, to_json(user_data))
    Error(err) -> handle_error(err)
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
    delete_user(db, id)
  }

  case result {
    Ok(_) -> json_response(ok, "{\"message\": \"User deleted\"}")
    Error(err) -> handle_error(err)
  }
}

/// Decoder for user create/update requests
fn user_decoder() -> Decoder(#(String, String)) {
  use name <- field("name", string)
  use email <- field("email", string)
  success(#(name, email))
}
