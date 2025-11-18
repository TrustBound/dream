//// Posts Controller - HTTP handlers
////
//// Handles HTTP concerns: parsing, error mapping, response building.
//// Demonstrates format negotiation and operation delegation.

import context.{type Context}
import dream/http/response.{html_response, json_response, stream_response}
import dream/http/status
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response}
import gleam/option
import models/post/post as post_model
import operations/export_posts
import operations/publish_post
import services.{type Services}
import types/errors.{type DataError, NotFound, Unauthorized}
import types/post.{type Post}
import views/post_view

/// List all posts
pub fn index(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  case post_model.list(services.db) {
    Ok(posts) -> json_response(status.ok, post_view.list_to_json(posts))
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

/// Show single post with format negotiation
pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case post_model.get(services.db, id) {
    Ok(post_data) -> respond_with_format(post_data, param.format)
    Error(NotFound) ->
      json_response(status.not_found, "{\"error\": \"Post not found\"}")
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

/// Publish a post (demonstrates operation usage)
pub fn publish(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(post_id) = param.as_int
  let user_id = 1
  // TODO: get from context once auth is added
  
  case publish_post.execute(post_id, user_id, services) {
    Ok(post_data) -> json_response(status.ok, post_view.to_json(post_data))
    Error(NotFound) ->
      json_response(status.not_found, "{\"error\": \"Post not found\"}")
    Error(Unauthorized) ->
      json_response(status.forbidden, "{\"error\": \"Unauthorized\"}")
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

/// Export posts as CSV (demonstrates streaming)
pub fn export(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  case export_posts.execute(services) {
    Ok(stream) -> stream_response(status.ok, stream, "text/csv")
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

// Private helpers

fn respond_with_format(
  post_data: Post,
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("json") -> json_response(status.ok, post_view.to_json(post_data))
    option.Some("csv") ->
      html_response(status.ok, post_view.to_csv(post_data))
    _ -> html_response(status.ok, post_view.to_html(post_data))
  }
}

