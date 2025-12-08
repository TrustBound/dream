//// Table Persistence
////
//// Example snippet showing how to save a table to disk.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn save_to_disk() -> Result(String, table.EtsError) {
  use table <- result.try(helpers.new_string_table("data"))

  use _ <- result.try(operations.set(table, "key", "important data"))

  // Save to disk
  use _ <- result.try(operations.save_to_file(table, "/tmp/dream_ets_test.ets"))

  // Verify it's still there
  use value <- result.try(operations.get(table, "key"))

  case value {
    option.Some(data) -> Ok(data)
    option.None -> Error(table.OperationFailed("Data lost"))
  }
}
