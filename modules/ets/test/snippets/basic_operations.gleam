//// Basic Operations
////
//// Example snippet showing set and get operations.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn store_and_retrieve() -> Result(String, table.EtsError) {
  use cache <- result.try(helpers.new_string_table("cache"))

  // Store a value
  use _ <- result.try(operations.set(cache, "greeting", "Hello, World!"))

  // Retrieve it
  use value <- result.try(operations.get(cache, "greeting"))

  case value {
    option.Some(greeting) -> Ok(greeting)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
