//// SECURITY.md: Dream checks the type of a parameter, and your code checks
//// the business rules.

import dream/http.{
  type Request, type Response, bad_request, not_found, ok, require_int,
  text_response,
}
import dream/http/error
import gleam/int
import gleam/list

/// The users that exist, by id.
pub type Database {
  Database(user_ids: List(Int))
}

pub fn show_user(request: Request, db: Database) -> Response {
  // Dream validates this is an integer
  case require_int(request, "user_id") {
    // YOU must validate business rules
    Ok(user_id) -> show_valid_user(db, user_id)
    Error(param_error) -> text_response(bad_request, error.message(param_error))
  }
}

fn show_valid_user(db: Database, user_id: Int) -> Response {
  case user_id > 0 {
    True -> fetch_user(db, user_id)
    False -> text_response(bad_request, "Invalid user ID")
  }
}

fn fetch_user(db: Database, user_id: Int) -> Response {
  case list.contains(db.user_ids, user_id) {
    True -> text_response(ok, "User " <> int.to_string(user_id))
    False -> text_response(not_found, "User not found")
  }
}
