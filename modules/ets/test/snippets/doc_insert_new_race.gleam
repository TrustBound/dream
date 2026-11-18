//// Doc comment: operations.insert_new
////
//// Compares member plus set (a race condition) with insert_new (atomic).

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result

// Race condition: another process can insert the key between the two calls
pub fn insert_if_missing_with_member(
  users: table.Table(String, String),
  key: String,
  value: String,
) -> Result(Bool, table.EtsError) {
  use exists <- result.try(operations.member(users, key))
  case exists {
    True -> Ok(False)
    False -> operations.set(users, key, value) |> result.replace(True)
  }
}

// Atomic: safe for concurrent access
pub fn insert_if_missing(
  users: table.Table(String, String),
  key: String,
  value: String,
) -> Result(Bool, table.EtsError) {
  operations.insert_new(users, key, value)
}

pub fn insert_twice_each_way() -> Result(List(Bool), table.EtsError) {
  use users <- result.try(helpers.new_string_table("doc_insert_new_race"))
  use first_member <- result.try(insert_if_missing_with_member(
    users,
    "alice",
    "Alice",
  ))
  use second_member <- result.try(insert_if_missing_with_member(
    users,
    "alice",
    "Alice",
  ))
  use first_atomic <- result.try(insert_if_missing(users, "bob", "Bob"))
  use second_atomic <- result.try(insert_if_missing(users, "bob", "Bob"))
  Ok([first_member, second_member, first_atomic, second_atomic])
}
