//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import context.{type DatabaseContext}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/core/http/validation.{validate_json}
import models/post
import services.{type Services}
import views/errors
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

  case validate_json(request.body, post.decoder()) {
    Error(_) -> errors.bad_request("Invalid post data")
    Ok(data) -> create_with_data(services, user_id, data)
  }
}

fn create_with_data(
  services: Services,
  user_id: Int,
  data: #(String, String),
) -> Response {
  let db = services.database.connection
  let #(title, content) = data
  post.create(db, user_id, title, content)
  |> post_view.respond_created()
}
