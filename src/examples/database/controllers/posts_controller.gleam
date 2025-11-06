//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import examples/database/context.{type DatabaseContext}
import examples/database/models/post
import examples/database/services.{type Services}
import gleam/int
import gleam/result

/// List all posts for a user
pub fn index(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  let assert Ok(user_id_str) = get_param(request, "user_id")
  let user_id = int.parse(user_id_str) |> result.unwrap(0)

  post.list(db, user_id)
  |> response.many_rows(post.encode_list)
}

/// Get a single post by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  let assert Ok(id_str) = get_param(request, "id")
  let id = int.parse(id_str) |> result.unwrap(0)

  post.get(db, id)
  |> response.one_row(post.encode)
}

/// Create a new post for a user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  let assert Ok(user_id_str) = get_param(request, "user_id")
  let user_id = int.parse(user_id_str) |> result.unwrap(0)

  case validate_or_respond(request.body, post.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(title, content) = data
      post.create(db, user_id, title, content)
      |> response.one_row(post.encode_create)
    }
  }
}
