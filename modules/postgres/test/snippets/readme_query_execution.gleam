//// README: Query Execution
////
//// Runs queries with Pog and turns the results into values with the query
//// helpers.

import dream_postgres/client as postgres
import dream_postgres/query
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string
import pog

pub type User {
  User(id: Int, name: String)
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  decode.success(User(id:, name:))
}

pub fn find_user(
  db: postgres.Connection,
  id: Int,
) -> Result(postgres.Returned(User), postgres.QueryError) {
  pog.query("SELECT id, name FROM users WHERE id = $1")
  |> pog.parameter(pog.int(id))
  |> pog.returning(user_decoder())
  |> pog.execute(db)
}

pub fn list_users(
  db: postgres.Connection,
) -> Result(postgres.Returned(User), postgres.QueryError) {
  pog.query("SELECT id, name FROM users")
  |> pog.returning(user_decoder())
  |> pog.execute(db)
}

// Get first row
pub fn describe_user(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> String {
  case query.first_row(result) {
    Ok(user) -> "User " <> int.to_string(user.id) <> ": " <> user.name
    Error(query.NotFound) -> "No such user"
    Error(query.DatabaseError) -> "The database query failed"
  }
}

// Get all rows
pub fn describe_user_count(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> String {
  case query.all_rows(result) {
    Ok(users) -> int.to_string(list.length(users)) <> " users"
    Error(error) -> "The database query failed: " <> string.inspect(error)
  }
}
