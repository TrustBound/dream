//// Starts the connection pool, then checks that the schema is still the
//// one that dream_model generated the models from.

import dream_postgres/client
import dream_postgres_client
import gleam/erlang/process
import gleam/io
import gleam/option
import gleam/otp/actor
import models/project
import models/tag
import models/task

pub fn initialize() -> dream_postgres_client.Connection {
  io.println("Connecting to database...")

  // Use direct dream_postgres_client configuration like other examples
  let pool_name = process.new_name("tasks_postgres_pool")

  let config =
    dream_postgres_client.default_config(pool_name: pool_name)
    |> dream_postgres_client.host("localhost")
    |> dream_postgres_client.port(5437)
    |> dream_postgres_client.database("tasks_db")
    |> dream_postgres_client.user("postgres")
    |> dream_postgres_client.password(option.Some("postgres"))
    |> dream_postgres_client.pool_size(10)

  let assert Ok(actor.Started(_pid, connection)) =
    dream_postgres_client.start(config)

  io.println("Database connection pool started")

  // Stop with a clear message when the schema changed after dream_model
  // generated the models
  case
    client.check_schema(connection, [
      project.schema_fingerprint,
      tag.schema_fingerprint,
      task.schema_fingerprint,
    ])
  {
    Ok(Nil) -> connection
    Error(error) -> panic as client.format_schema_check_error(error)
  }
}
