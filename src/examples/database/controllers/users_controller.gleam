//// Users Controller
////
//// Demonstrates CRUD operations for users using type-safe Squirrel queries

import dream/core/http/statuses.{
  created_status, internal_server_error_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{
  type Request, type Response, get_param, json_response, text_response,
}
import dream/validators/json_validator.{type ValidationError, error_response, validate}
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

fn convert_validation_error(error: ValidationError) -> Response {
  error_response(error)
}

fn map_database_error(_error: pog.QueryError) -> String {
  "Database error"
}

fn map_no_rows_error(_error: String) -> String {
  "No rows returned"
}

fn map_user_not_found_error(_error: String) -> String {
  "User not found"
}

fn convert_nil_to_string(_error: Nil) -> String {
  ""
}

fn get_first_user_row(db_result: pog.Returned(sql.GetUserRow)) -> Result(sql.GetUserRow, String) {
  list.first(db_result.rows)
  |> result.map_error(convert_nil_to_string)
}

fn get_first_user_row_from_create(db_result: pog.Returned(sql.CreateUserRow)) -> Result(sql.CreateUserRow, String) {
  list.first(db_result.rows)
  |> result.map_error(convert_nil_to_string)
}

fn get_first_user_row_from_update(db_result: pog.Returned(sql.UpdateUserRow)) -> Result(sql.UpdateUserRow, String) {
  list.first(db_result.rows)
  |> result.map_error(convert_nil_to_string)
}

fn create_user_response(user_row: sql.CreateUserRow) -> Response {
  let user_json = format_user_as_json_from_create(user_row)
  json_response(created_status(), user_json)
}

fn create_user_failure_response(_error: String) -> Response {
  text_response(
    internal_server_error_status(),
    "Failed to create user",
  )
}

fn update_user_response(user_row: sql.UpdateUserRow) -> Response {
  let user_json = format_user_as_json_from_update(user_row)
  json_response(ok_status(), user_json)
}

fn update_user_failure_response(_error: String) -> Response {
  text_response(internal_server_error_status(), "Failed to update user")
}

fn create_user_from_validated_data(
  data: #(String, String),
  services: Services,
) -> Result(Response, Response) {
  let #(name, email) = data
  sql.create_user(services.database.connection, name, email)
  |> result.map_error(map_database_error)
  |> result.try(get_first_user_row_from_create)
  |> result.map_error(map_no_rows_error)
  |> result.map(create_user_response)
  |> result.map_error(create_user_failure_response)
}

fn update_user_from_validated_data(
  data: #(String, String),
  id: Int,
  services: Services,
) -> Result(Response, Response) {
  let #(name, email) = data
  sql.update_user(
    services.database.connection,
    name,
    email,
    id,
  )
  |> result.map_error(map_database_error)
  |> result.try(get_first_user_row_from_update)
  |> result.map_error(map_user_not_found_error)
  |> result.map(update_user_response)
  |> result.map_error(update_user_failure_response)
}

fn process_create_user_request(
  data: #(String, String),
  services: Services,
) -> Result(Response, Response) {
  create_user_from_validated_data(data, services)
}

fn process_update_user_request(
  data: #(String, String),
  id: Int,
  services: Services,
) -> Result(Response, Response) {
  update_user_from_validated_data(data, id, services)
}

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
    |> result.map_error(map_database_error)
    |> result.try(get_first_user_row)
    |> result.map_error(map_user_not_found_error)
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
  let decoder = {
    use name <- decode.field("name", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, email))
  }

  let validation_result = validate(request.body, decoder)

  case validation_result {
    Error(error) -> error_response(error)
    Ok(data) ->
      process_create_user_request(data, services)
      |> result.unwrap(text_response(internal_server_error_status(), ""))
  }
}

/// Update a user
pub fn update(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let assert Ok(id) = get_param(request, "id")

  let decoder = {
    use name <- decode.field("name", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, email))
  }

  let validation_result = validate(request.body, decoder)

  case validation_result {
    Error(error) -> error_response(error)
    Ok(data) ->
      process_update_user_request(
        data,
        int.parse(id) |> result.unwrap(0),
        services,
      )
      |> result.unwrap(text_response(internal_server_error_status(), ""))
  }
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
