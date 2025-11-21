//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int}
import dream/http/error.{type Error, BadRequest}
import dream/http/response.{json_response}
import dream/http/status
import dream/http/validation.{validate_json}
import gleam/result
import models/post
import operations/post_operations
import services.{type Services}
import utilities/response_helpers
import views/post_view

fn parse_post_data(body: String) -> Result(#(String, String), Error) {
  case validate_json(body, post.decoder()) {
    Ok(d) -> Ok(d)
    Error(_) -> Error(BadRequest("Invalid post data"))
  }
}

/// List all posts for a user
pub fn index(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use user_id <- result.try(require_int(request, "user_id"))
    let db = services.database.connection
    post_operations.list_posts(db, user_id)
  }

  case result {
    Ok(posts) -> json_response(status.ok, post_view.list_to_json(posts))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Get a single post by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    post_operations.get_post(db, id)
  }

  case result {
    Ok(post_data) -> json_response(status.ok, post_view.to_json(post_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Create a new post for a user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use user_id <- result.try(require_int(request, "user_id"))
    use data <- result.try(parse_post_data(request.body))
    let #(title, content) = data
    let db = services.database.connection
    post_operations.create_post(db, user_id, title, content)
  }

  case result {
    Ok(post_data) -> json_response(status.created, post_view.to_json(post_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}
