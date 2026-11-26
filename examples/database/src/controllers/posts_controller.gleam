//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using the model that dream_model generates
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int, require_json}
import dream/http/response.{json_response}
import dream/http/status
import gleam/dynamic/decode.{type Decoder, field, string, success}
import gleam/result
import operations/post_operations
import services.{type Services}
import utilities/response_helpers
import views/post_view

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
    use #(title, content) <- result.try(require_json(request, post_decoder()))
    let db = services.database.connection
    post_operations.create_post(db, user_id, title, content)
  }

  case result {
    Ok(post_data) -> json_response(status.created, post_view.to_json(post_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Decoder for post create requests
fn post_decoder() -> Decoder(#(String, String)) {
  use title <- field("title", string)
  use content <- field("content", string)
  success(#(title, content))
}
