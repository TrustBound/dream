//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, json_response}
import dream/http/status
import dream/http/validation.{validate_json}
import models/post
import services.{type Services}
import types/errors
import views/errors as error_responses
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
  case post.list(db, user_id) {
    Ok(posts) -> json_response(status.ok, post_view.list_to_json(posts))
    Error(_) -> error_responses.internal_error()
  }
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
  case post.get(db, id) {
    Ok(post_data) -> json_response(status.ok, post_view.to_json(post_data))
    Error(errors.NotFound) -> error_responses.not_found("Post not found")
    Error(_) -> error_responses.internal_error()
  }
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
    Error(_) -> error_responses.bad_request("Invalid post data")
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
  case post.create(db, user_id, title, content) {
    Ok(post_data) -> json_response(status.created, post_view.to_json(post_data))
    Error(_) -> error_responses.internal_error()
  }
}
