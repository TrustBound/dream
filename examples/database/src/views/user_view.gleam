//// User view - presentation logic for users
////
//// This module handles all presentation concerns for user data,
//// converting model data into HTTP responses. All JSON encoding lives here.

import dream/core/http/statuses.{created_status, ok_status}
import dream/core/http/transaction.{type Response, json_response}
import dream/utilities/json/encoders
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog
import sql
import views/errors

/// Respond with a single user (for show action)
pub fn respond(
  result: Result(pog.Returned(sql.GetUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_with_rows(rows: List(sql.GetUserRow)) -> Response {
  case rows {
    [user] -> json_response(ok_status(), to_json(user))
    [] -> errors.not_found("User not found")
    _ -> errors.not_found("User not found")
  }
}

/// Respond with a list of users (for index action)
pub fn respond_list(
  result: Result(pog.Returned(sql.ListUsersRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> json_response(ok_status(), list_to_json(returned.rows))
    Error(_) -> errors.internal_error()
  }
}

/// Respond with a created user (for create action)
pub fn respond_created(
  result: Result(pog.Returned(sql.CreateUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_created_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_created_with_rows(rows: List(sql.CreateUserRow)) -> Response {
  case rows {
    [user] -> json_response(created_status(), to_json_created(user))
    [] -> errors.internal_error()
    _ -> errors.internal_error()
  }
}

/// Respond with an updated user (for update action)
pub fn respond_updated(
  result: Result(pog.Returned(sql.UpdateUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_updated_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_updated_with_rows(rows: List(sql.UpdateUserRow)) -> Response {
  case rows {
    [user] -> json_response(ok_status(), to_json_updated(user))
    [] -> errors.not_found("User not found")
    _ -> errors.not_found("User not found")
  }
}

/// Respond with success for delete action
pub fn respond_deleted(
  result: Result(pog.Returned(Nil), pog.QueryError),
) -> Response {
  case result {
    Ok(_) -> json_response(ok_status(), "{\"message\": \"User deleted\"}")
    Error(_) -> errors.not_found("User not found")
  }
}

// Private helper functions - JSON encoding

fn to_json(user: sql.GetUserRow) -> String {
  encode_user(user.id, user.name, user.email, user.created_at)
  |> json.to_string()
}

fn to_json_created(user: sql.CreateUserRow) -> String {
  encode_user(user.id, user.name, user.email, user.created_at)
  |> json.to_string()
}

fn to_json_updated(user: sql.UpdateUserRow) -> String {
  encode_user(user.id, user.name, user.email, user.created_at)
  |> json.to_string()
}

fn list_to_json(users: List(sql.ListUsersRow)) -> String {
  users
  |> list.map(fn(user) {
    encode_user(user.id, user.name, user.email, user.created_at)
  })
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

/// Shared JSON encoder for all user row types
fn encode_user(
  id: Int,
  name: String,
  email: String,
  created_at: option.Option(timestamp.Timestamp),
) -> json.Json {
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("email", json.string(email)),
    #("created_at", encoders.timestamp(created_at)),
  ])
}

