//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import dream/core/http/transaction.{type PathParam, type Request, type Response, get_param}
import dream/services/postgres/response
import dream/validators/json_validator.{validate_or_respond}
import context.{type DatabaseContext}
import models/post
import services.{type Services}
import pog

/// List all posts for a user
pub fn index(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case get_param(request, "user_id") {
    Error(_) -> response.bad_request()
    Ok(param) -> index_with_param(param, services)
  }
}

fn index_with_param(param: PathParam, services: Services) -> Response {
  case param.as_int {
    Error(_) -> response.bad_request()
    Ok(user_id) -> list_posts(user_id, services)
  }
}

fn list_posts(user_id: Int, services: Services) -> Response {
  let db = services.database.connection
  post.list(db, user_id)
  |> response.many_rows(post.encode_list)
}

/// Get a single post by ID
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
    Ok(id) -> show_post(id, services)
  }
}

fn show_post(id: Int, services: Services) -> Response {
  let db = services.database.connection
  post.get(db, id)
  |> response.one_row(post.encode)
}

/// Create a new post for a user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case get_param(request, "user_id") {
    Error(_) -> response.bad_request()
    Ok(param) -> create_with_param(param, request, services)
  }
}

fn create_with_param(
  param: PathParam,
  request: Request,
  services: Services,
) -> Response {
  case param.as_int {
    Error(_) -> response.bad_request()
    Ok(user_id) -> create_post(user_id, request, services)
  }
}

fn create_post(user_id: Int, request: Request, services: Services) -> Response {
  let db = services.database.connection
  case validate_or_respond(request.body, post.decoder()) {
    Error(response) -> response
    Ok(data) -> create_post_with_data(user_id, data, db)
  }
}

fn create_post_with_data(
  user_id: Int,
  data: #(String, String),
  db: pog.Connection,
) -> Response {
  let #(title, content) = data
  post.create(db, user_id, title, content)
  |> response.one_row(post.encode_create)
}
