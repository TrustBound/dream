//// Database Initialization
////
//// Sets up the PostgreSQL connection pool.
//// Note: Database migrations should be run separately (e.g., via `make migrate`)
//// before starting the application to avoid race conditions with multiple instances.

import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import pog

pub type DatabaseService {
  DatabaseService(connection: pog.Connection)
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    pog.default_config(pool_name: pool_name)
    |> pog.host("localhost")
    |> pog.port(5435)
    |> pog.database("dream_example_database_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)

  // Start the connection pool
  case pog.start(config) {
    Ok(actor.Started(_pid, connection)) -> {
      Ok(DatabaseService(connection: connection))
    }
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  }
}
