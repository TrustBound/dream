//// Session Cache
////
//// Example snippet showing a table of session IDs and user IDs.

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn store_session() -> Result(option.Option(String), table.EtsError) {
  use sessions <- result.try(
    config.new("sessions")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  use _ <- result.try(operations.set(sessions, "session:abc", "user:alice"))
  operations.get(sessions, "session:abc")
}
