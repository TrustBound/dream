//// Posts Controller
////
//// Demonstrates CRUD operations for posts with user relationships using type-safe Squirrel queries

import dream/core/http/statuses.{
  created_status, internal_server_error_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{
  type Request, type Response, get_param, json_response, text_response,
}
import examples/database/context.{type DatabaseContext}
import examples/database/services.{type Services}
import examples/database/sql
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

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
    |> result.map_error(fn(_) { "Database error" })
    |> result.try(fn(db_result) {
      list.first(db_result.rows)
      |> result.map_error(fn(_) { "Post not found" })
    })
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

  case
    parse_create_post_body(request.body)
    |> result.try(fn(data) {
      let #(title, content) = data
      sql.create_post(
        services.database.connection,
        int.parse(user_id) |> result.unwrap(0),
        title,
        content,
      )
      |> result.map_error(fn(_) { "Database error" })
    })
    |> result.try(fn(db_result) {
      list.first(db_result.rows)
      |> result.map_error(fn(_) { "No rows returned" })
    })
  {
    Ok(post_row) -> {
      let post_json = format_post_as_json_from_create(post_row)
      json_response(created_status(), post_json)
    }
    Error(error) -> {
      text_response(
        internal_server_error_status(),
        "Failed to create post: " <> error,
      )
    }
  }
}

fn parse_create_post_body(body: String) -> Result(#(String, String), String) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use content <- decode.field("content", decode.string)
    decode.success(#(title, content))
  }

  json.parse(body, decode.dynamic)
  |> result.map_error(format_json_error)
  |> result.try(fn(json_obj) {
    decode.run(json_obj, decoder)
    |> result.map_error(fn(errors) {
      case list.first(errors) {
        Ok(decode.DecodeError(expected, found, path)) -> {
          "Expected "
          <> expected
          <> " but found "
          <> found
          <> " at "
          <> string.join(path, ".")
        }
        Error(_) -> "Decode error"
      }
    })
  })
}

fn format_json_error(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "Unexpected end of JSON input"
    json.UnexpectedByte(msg) -> "Unexpected byte: " <> msg
    json.UnexpectedSequence(msg) -> "Unexpected sequence: " <> msg
    json.UnableToDecode(errors) ->
      "Unable to decode: " <> string.inspect(errors)
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
