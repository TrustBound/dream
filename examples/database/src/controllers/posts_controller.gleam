//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import context.{type DatabaseContext}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream_helpers/validators.{validate_or_respond}
import models/post
import services.{type Services}
import views/post_view

/// List all posts for a user
pub fn index(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "user_id")
  let assert Ok(user_id) = param.as_int

  let db = services.database.connection
  post.list(db, user_id)
  |> post_view.respond_list()
}

/// Get a single post by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  let db = services.database.connection
  post.get(db, id)
  |> post_view.respond()
}

/// Create a new post for a user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "user_id")
  let assert Ok(user_id) = param.as_int

  let db = services.database.connection
  case validate_or_respond(request.body, post.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(title, content) = data
      post.create(db, user_id, title, content)
      |> post_view.respond_created()
    }
  }
}
