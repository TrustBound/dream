//// Database Initialization
////
//// Sets up the PostgreSQL connection pool.
//// Note: Database migrations should be run separately (e.g., via `make migrate`)
//// before starting the application to avoid race conditions with multiple instances.

import dream/core/singleton
import dream/services/postgres
import dream/services/service.{type DatabaseService}
import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import pog

pub fn db_name() -> process.Name(
  singleton.SingletonMessage(postgres.PostgresMessage, postgres.PostgresReply),
) {
  process.new_name("dream_database")
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    pog.default_config(pool_name: pool_name)
    |> pog.host("localhost")
    |> pog.port(5434)
    |> pog.database("dream_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)

  // Start the connection pool
  case pog.start(config) {
    Ok(actor.Started(_pid, connection)) -> {
      // Start the postgres singleton service
      let name = db_name()
      case postgres.start_with_connection(name, connection) {
        Ok(_) -> Ok(service.DatabaseService(connection: connection, name: name))
        Error(e) -> Error("Failed to start postgres service: " <> e)
      }
    }
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  }
}
