//// Insert New
////
//// Example snippet showing how to prevent duplicate entries with insert_new.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result

pub fn register_user() -> Result(Bool, table.EtsError) {
  use registrations <- result.try(helpers.new_string_table("registrations"))

  // Try to register username
  use registered <- result.try(operations.insert_new(
    registrations,
    "alice",
    "alice@example.com",
  ))

  case registered {
    True -> {
      // Username available - registration succeeded
      Ok(True)
    }
    False -> {
      // Username already taken
      Ok(False)
    }
  }
}
