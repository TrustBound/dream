//// Error Handling
////
//// Example snippet showing how to handle each result of a lookup.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result
import gleam/string

pub fn describe_lookup(
  users: table.Table(String, String),
  key: String,
) -> String {
  case operations.get(users, key) {
    Ok(option.Some(user)) -> "Found " <> user
    Ok(option.None) -> "No user for " <> key
    Error(table.DecodeError(error)) ->
      "Stored data is corrupt: expected "
      <> error.expected
      <> ", found "
      <> error.found
    Error(table.TableNotFound) -> "The table was deleted"
    Error(other) -> "Lookup failed: " <> string.inspect(other)
  }
}

pub fn describe_two_lookups() -> Result(List(String), table.EtsError) {
  use users <- result.try(helpers.new_string_table("error_handling_users"))
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  let found = describe_lookup(users, "user:123")
  let missing = describe_lookup(users, "user:456")
  Ok([found, missing])
}
