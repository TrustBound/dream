//// Type-Safe Operations
////
//// Example snippet demonstrating compile-time type safety.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn type_safe_storage() -> Result(String, table.EtsError) {
  // String table enforces types at compile time
  use cache <- result.try(helpers.new_string_table("cache"))

  // ✅ This works
  use _ <- result.try(operations.set(cache, "key", "value"))

  // ❌ This would be a compile error:
  // operations.set(cache, 123, "value")
  // Error: Expected String, found Int

  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(v) -> Ok(v)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
