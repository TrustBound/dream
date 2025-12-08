//// Creating Tables
////
//// Example snippet showing how to create an ETS table.

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn create_string_table() -> Result(String, table.EtsError) {
  // Create a table using the builder pattern
  use cache <- result.try(
    config.new("user_cache")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Use it
  use _ <- result.try(operations.set(cache, "alice", "Alice"))
  use value <- result.try(operations.get(cache, "alice"))

  case value {
    option.Some(name) -> Ok(name)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
