//// Doc comment: operations.member
////
//// Checks whether a key is in the table, and handles each result.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result
import gleam/string

pub fn describe_user(
  users: table.Table(String, String),
  user_id: String,
) -> String {
  case operations.member(users, user_id) {
    Ok(True) -> user_id <> " exists"
    Ok(False) -> user_id <> " does not exist"
    Error(table.TableNotFound) -> "The table was deleted"
    Error(other) -> "Check failed: " <> string.inspect(other)
  }
}

pub fn describe_users_before_and_after_delete() -> Result(
  List(String),
  table.EtsError,
) {
  use users <- result.try(helpers.new_string_table("doc_member_users"))
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  let found = describe_user(users, "user:123")
  let missing = describe_user(users, "user:456")
  use _ <- result.try(operations.delete_table(users))
  let deleted = describe_user(users, "user:123")
  Ok([found, missing, deleted])
}
