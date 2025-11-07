//// User view - presentation logic for users
////
//// This module handles all presentation concerns for user data,
//// converting model data into HTTP responses.

import dream/core/http/statuses.{
  created_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{type Response, json_response}
import gleam/json
import gleam/list
import models/user
import pog
import sql

/// Respond with a single user (for show action)
pub fn respond(
  result: Result(pog.Returned(sql.GetUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> {
      case returned.rows {
        [user] -> json_response(ok_status(), to_json(user))
        [] -> not_found_response()
        _ -> not_found_response()
      }
    }
    Error(_) -> not_found_response()
  }
}

/// Respond with a list of users (for index action)
pub fn respond_list(
  result: Result(pog.Returned(sql.ListUsersRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> json_response(ok_status(), list_to_json(returned.rows))
    Error(_) -> error_response()
  }
}

/// Respond with a created user (for create action)
pub fn respond_created(
  result: Result(pog.Returned(sql.CreateUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> {
      case returned.rows {
        [user] -> json_response(created_status(), to_json_created(user))
        [] -> error_response()
        _ -> error_response()
      }
    }
    Error(_) -> error_response()
  }
}

/// Respond with an updated user (for update action)
pub fn respond_updated(
  result: Result(pog.Returned(sql.UpdateUserRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> {
      case returned.rows {
        [user] -> json_response(ok_status(), to_json_updated(user))
        [] -> not_found_response()
        _ -> not_found_response()
      }
    }
    Error(_) -> not_found_response()
  }
}

/// Respond with success for delete action
pub fn respond_deleted(
  result: Result(pog.Returned(Nil), pog.QueryError),
) -> Response {
  case result {
    Ok(_) -> json_response(ok_status(), "{\"message\": \"User deleted\"}")
    Error(_) -> not_found_response()
  }
}

// Private helper functions

fn to_json(user: sql.GetUserRow) -> String {
  user.encode(user)
  |> json.to_string()
}

fn to_json_created(user: sql.CreateUserRow) -> String {
  user.encode_create(user)
  |> json.to_string()
}

fn to_json_updated(user: sql.UpdateUserRow) -> String {
  user.encode_update(user)
  |> json.to_string()
}

fn list_to_json(users: List(sql.ListUsersRow)) -> String {
  users
  |> list.map(user.encode_list)
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

fn not_found_response() -> Response {
  json_response(not_found_status(), "{\"error\": \"User not found\"}")
}

fn error_response() -> Response {
  json_response(
    statuses.internal_server_error_status(),
    "{\"error\": \"Internal server error\"}",
  )
}

