//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import dream/core/http/statuses.{
  created_status, internal_server_error_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{
  type Request, type Response, get_param, json_response, text_response,
}
import dream/validators/json_validator.{error_response, validate}
import examples/database/context.{type DatabaseContext}
import examples/database/services.{type Services}
import examples/database/sql
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import pog

fn map_database_error(_error: pog.QueryError) -> String {
  "Database error"
}

fn map_no_rows_error(_error: String) -> String {
  "No rows returned"
}

fn map_post_not_found_error(_error: String) -> String {
  "Post not found"
}

fn convert_nil_to_string(_error: Nil) -> String {
  ""
}

fn get_first_post_row(
  db_result: pog.Returned(sql.GetPostRow),
) -> Result(sql.GetPostRow, String) {
  list.first(db_result.rows)
  |> result.map_error(convert_nil_to_string)
}

fn get_first_post_row_from_create(
  db_result: pog.Returned(sql.CreatePostRow),
) -> Result(sql.CreatePostRow, String) {
  list.first(db_result.rows)
  |> result.map_error(convert_nil_to_string)
}

fn create_post_response(post_row: sql.CreatePostRow) -> Response {
  let post_json = format_post_as_json_from_create(post_row)
  json_response(created_status(), post_json)
}

fn create_post_failure_response(_error: String) -> Response {
  text_response(internal_server_error_status(), "Failed to create post")
}

fn create_post_from_validated_data(
  data: #(String, String),
  user_id: Int,
  services: Services,
) -> Result(Response, Response) {
  let #(title, content) = data
  sql.create_post(services.database.connection, user_id, title, content)
  |> result.map_error(map_database_error)
  |> result.try(get_first_post_row_from_create)
  |> result.map_error(map_no_rows_error)
  |> result.map(create_post_response)
  |> result.map_error(create_post_failure_response)
}

fn process_create_post_request(
  data: #(String, String),
  user_id: Int,
  services: Services,
) -> Result(Response, Response) {
  create_post_from_validated_data(data, user_id, services)
}

/// List all posts for a user
pub fn index(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(user_id) = get_param(request, "user_id")

  case
    sql.list_posts(
      services.database.connection,
      int.parse(user_id) |> result.unwrap(0),
    )
  {
    Ok(result) -> {
      let posts_json = format_posts_as_json(result.rows)
      json_response(ok_status(), posts_json)
    }
    Error(_) -> {
      text_response(internal_server_error_status(), "Failed to query posts")
    }
  }
}

/// Get a single post by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(id) = get_param(request, "id")

  case
    sql.get_post(
      services.database.connection,
      int.parse(id) |> result.unwrap(0),
    )
    |> result.map_error(map_database_error)
    |> result.try(get_first_post_row)
    |> result.map_error(map_post_not_found_error)
  {
    Ok(post_row) -> {
      let post_json = format_post_as_json(post_row)
      json_response(ok_status(), post_json)
    }
    Error(_) -> {
      text_response(not_found_status(), "Post not found")
    }
  }
}

/// Create a new post for a user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(user_id) = get_param(request, "user_id")

  let decoder = {
    use title <- decode.field("title", decode.string)
    use content <- decode.field("content", decode.string)
    decode.success(#(title, content))
  }

  let validation_result = validate(request.body, decoder)

  case validation_result {
    Error(error) -> error_response(error)
    Ok(data) ->
      process_create_post_request(
        data,
        int.parse(user_id) |> result.unwrap(0),
        services,
      )
      |> result.unwrap(text_response(internal_server_error_status(), ""))
  }
}

// JSON formatting functions using type-safe row types
fn format_posts_as_json(rows: List(sql.ListPostsRow)) -> String {
  let formatted = list.map(rows, format_post_row_as_json)
  "[" <> string.join(formatted, ",") <> "]"
}

fn format_post_as_json(post: sql.GetPostRow) -> String {
  format_post_row_as_json_from_get(post)
}

fn format_post_as_json_from_create(post: sql.CreatePostRow) -> String {
  format_post_row_as_json_from_create(post)
}

fn format_post_row_as_json(post: sql.ListPostsRow) -> String {
  let content_str = case post.content {
    option.Some(text) -> "\"" <> text <> "\""
    option.None -> "null"
  }
  let created_at_str = case post.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(post.id)
  <> ",\"user_id\":"
  <> int.to_string(post.user_id)
  <> ",\"title\":\""
  <> post.title
  <> "\",\"content\":"
  <> content_str
  <> ",\"created_at\":"
  <> created_at_str
  <> "}"
}

fn format_post_row_as_json_from_get(post: sql.GetPostRow) -> String {
  let content_str = case post.content {
    option.Some(text) -> "\"" <> text <> "\""
    option.None -> "null"
  }
  let created_at_str = case post.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(post.id)
  <> ",\"user_id\":"
  <> int.to_string(post.user_id)
  <> ",\"title\":\""
  <> post.title
  <> "\",\"content\":"
  <> content_str
  <> ",\"created_at\":"
  <> created_at_str
  <> "}"
}

fn format_post_row_as_json_from_create(post: sql.CreatePostRow) -> String {
  let content_str = case post.content {
    option.Some(text) -> "\"" <> text <> "\""
    option.None -> "null"
  }
  let created_at_str = case post.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(post.id)
  <> ",\"user_id\":"
  <> int.to_string(post.user_id)
  <> ",\"title\":\""
  <> post.title
  <> "\",\"content\":"
  <> content_str
  <> ",\"created_at\":"
  <> created_at_str
  <> "}"
}
