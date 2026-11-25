//// Database Initialization
////
//// Sets up the PostgreSQL connection pool.
//// Note: Database migrations should be run separately (e.g., via `make migrate`)
//// before starting the application to avoid race conditions with multiple instances.
//// After the pool starts, the app checks that the schema is still the one
//// that dream_model generated the models from.

import dream_postgres/client
import dream_postgres_client
import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import gleam/result
import models/post
import models/user

pub type DatabaseService {
  DatabaseService(connection: dream_postgres_client.Connection)
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    dream_postgres_client.default_config(pool_name: pool_name)
    |> dream_postgres_client.host("localhost")
    |> dream_postgres_client.port(5435)
    |> dream_postgres_client.database("dream_example_database_db")
    |> dream_postgres_client.user("postgres")
    |> dream_postgres_client.password(option.Some("postgres"))
    |> dream_postgres_client.pool_size(10)

  // Start the connection pool
  use connection <- result.try(case dream_postgres_client.start(config) {
    Ok(actor.Started(_pid, connection)) -> Ok(connection)
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  })

  // Stop with a clear message when the schema changed after dream_model
  // generated the models
  use Nil <- result.try(
    client.check_schema(connection, [
      user.schema_fingerprint,
      post.schema_fingerprint,
    ])
    |> result.map_error(client.format_schema_check_error),
  )
  Ok(DatabaseService(connection: connection))
}
