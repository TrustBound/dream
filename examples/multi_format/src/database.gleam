//// Database Initialization for multi-format example

import dream_postgres_client
import gleam/erlang/process
import gleam/option
import gleam/otp/actor

pub type DatabaseService {
  DatabaseService(connection: dream_postgres_client.Connection)
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("multi_format_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    dream_postgres_client.default_config(pool_name: pool_name)
    |> dream_postgres_client.host("localhost")
    |> dream_postgres_client.port(5435)
    |> dream_postgres_client.database("dream_example_multi_format_db")
    |> dream_postgres_client.user("postgres")
    |> dream_postgres_client.password(option.Some("postgres"))
    |> dream_postgres_client.pool_size(10)

  // Start the connection pool
  case dream_postgres_client.start(config) {
    Ok(actor.Started(_pid, connection)) -> {
      Ok(DatabaseService(connection: connection))
    }
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  }
}
