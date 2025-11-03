//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

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

/// List all users
pub fn index(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case sql.list_users(services.database.connection) {
    Ok(result) -> {
      let users_json = format_users_as_json(result.rows)
      json_response(ok_status(), users_json)
    }
    Error(_) -> {
      text_response(internal_server_error_status(), "Failed to query users")
    }
  }
}

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(id) = get_param(request, "id")

  case
    sql.get_user(
      services.database.connection,
      int.parse(id) |> result.unwrap(0),
    )
    |> result.map_error(fn(_) { "Database error" })
    |> result.try(fn(db_result) {
      list.first(db_result.rows)
      |> result.map_error(fn(_) { "User not found" })
    })
  {
    Ok(user_row) -> {
      let user_json = format_user_as_json(user_row)
      json_response(ok_status(), user_json)
    }
    Error(_) -> {
      text_response(not_found_status(), "User not found")
    }
  }
}

/// Create a new user
pub fn create(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case
    parse_create_user_body(request.body)
    |> result.try(fn(data) {
      let #(name, email) = data
      sql.create_user(services.database.connection, name, email)
      |> result.map_error(fn(_) { "Database error" })
    })
    |> result.try(fn(db_result) {
      list.first(db_result.rows)
      |> result.map_error(fn(_) { "No rows returned" })
    })
  {
    Ok(user_row) -> {
      let user_json = format_user_as_json_from_create(user_row)
      json_response(created_status(), user_json)
    }
    Error(error) -> {
      text_response(
        internal_server_error_status(),
        "Invalid request body: " <> error,
      )
    }
  }
}

fn parse_create_user_body(body: String) -> Result(#(String, String), String) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, email))
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

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(id) = get_param(request, "id")

  case
    parse_update_user_body(request.body)
    |> result.try(fn(data) {
      let #(name, email) = data
      sql.update_user(
        services.database.connection,
        name,
        email,
        int.parse(id) |> result.unwrap(0),
      )
      |> result.map_error(fn(_) { "Database error" })
    })
    |> result.try(fn(db_result) {
      list.first(db_result.rows)
      |> result.map_error(fn(_) { "User not found" })
    })
  {
    Ok(user_row) -> {
      let user_json = format_user_as_json_from_update(user_row)
      json_response(ok_status(), user_json)
    }
    Error(_) -> {
      text_response(internal_server_error_status(), "Failed to update user")
    }
  }
}

fn parse_update_user_body(body: String) -> Result(#(String, String), String) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, email))
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

/// Delete a user
pub fn delete(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(id) = get_param(request, "id")

  case
    sql.delete_user(
      services.database.connection,
      int.parse(id) |> result.unwrap(0),
    )
  {
    Ok(_) -> text_response(ok_status(), "User deleted")
    Error(_) -> {
      text_response(internal_server_error_status(), "Failed to delete user")
    }
  }
}

// JSON formatting functions using type-safe row types
fn format_users_as_json(rows: List(sql.ListUsersRow)) -> String {
  let formatted = list.map(rows, format_user_row_as_json)
  "[" <> string.join(formatted, ",") <> "]"
}

fn format_user_as_json(user: sql.GetUserRow) -> String {
  format_user_row_as_json_from_get(user)
}

fn format_user_as_json_from_create(user: sql.CreateUserRow) -> String {
  format_user_row_as_json_from_create(user)
}

fn format_user_as_json_from_update(user: sql.UpdateUserRow) -> String {
  format_user_row_as_json_from_update(user)
}

fn format_user_row_as_json(user: sql.ListUsersRow) -> String {
  let created_at_str = case user.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(user.id)
  <> ",\"name\":\""
  <> user.name
  <> "\",\"email\":\""
  <> user.email
  <> "\",\"created_at\":"
  <> created_at_str
  <> "}"
}

fn format_user_row_as_json_from_get(user: sql.GetUserRow) -> String {
  let created_at_str = case user.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(user.id)
  <> ",\"name\":\""
  <> user.name
  <> "\",\"email\":\""
  <> user.email
  <> "\",\"created_at\":"
  <> created_at_str
  <> "}"
}

fn format_user_row_as_json_from_create(user: sql.CreateUserRow) -> String {
  let created_at_str = case user.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(user.id)
  <> ",\"name\":\""
  <> user.name
  <> "\",\"email\":\""
  <> user.email
  <> "\",\"created_at\":"
  <> created_at_str
  <> "}"
}

fn format_user_row_as_json_from_update(user: sql.UpdateUserRow) -> String {
  let created_at_str = case user.created_at {
    option.Some(timestamp) -> string.inspect(timestamp)
    option.None -> "null"
  }
  "{"
  <> "\"id\":"
  <> int.to_string(user.id)
  <> ",\"name\":\""
  <> user.name
  <> "\",\"email\":\""
  <> user.email
  <> "\",\"created_at\":"
  <> created_at_str
  <> "}"
}
