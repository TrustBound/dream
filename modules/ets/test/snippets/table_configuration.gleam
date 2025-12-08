//// Table Configuration
////
//// Example snippet showing table configuration options.

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn configure_table() -> Result(String, table.EtsError) {
  // Create table with read concurrency enabled
  // Use this when multiple processes will read simultaneously
  use cache <- result.try(
    config.new("cache")
    |> config.read_concurrency(True)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  use _ <- result.try(operations.set(cache, "key", "value"))
  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(v) -> Ok(v)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
