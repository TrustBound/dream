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
import gleam/int
import gleam/io
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

  // Wait for the database, then stop with a clear message when the schema
  // changed after dream_model generated the models
  use Nil <- result.try(
    check_schema_waiting_for_database(connection, [
      user.schema_fingerprint,
      post.schema_fingerprint,
    ])
    |> result.map_error(client.format_schema_check_error),
  )
  Ok(DatabaseService(connection: connection))
}

/// How many times the app runs the schema check while the database cannot
/// be reached. With `schema_check_delay_ms`, the app waits 28 seconds in all
/// between the attempts. Each failed check also takes 2 to 3 seconds, the
/// time that the pool waits for a connection.
const schema_check_attempts = 15

/// The time between two schema checks, in milliseconds
const schema_check_delay_ms = 2000

/// Runs `client.check_schema`, and waits for a database that cannot be
/// reached yet. When the pool has no connection, it prints one line, waits
/// `schema_check_delay_ms` and runs the check again, at most
/// `schema_check_attempts` times. A changed schema and the other database
/// errors give the error at once.
pub fn check_schema_waiting_for_database(
  connection: dream_postgres_client.Connection,
  expected: List(client.SchemaFingerprint),
) -> Result(Nil, client.SchemaCheckError) {
  check_schema_attempt(connection, expected, 1)
}

fn check_schema_attempt(
  connection: dream_postgres_client.Connection,
  expected: List(client.SchemaFingerprint),
  attempt: Int,
) -> Result(Nil, client.SchemaCheckError) {
  case client.check_schema(connection, expected) {
    Error(
      client.SchemaUnreadable(
        error: dream_postgres_client.ConnectionUnavailable,
        ..,
      ) as error,
    )
      if attempt < schema_check_attempts
    -> {
      io.println_error(
        "Waiting for the database (attempt "
        <> int.to_string(attempt)
        <> " of "
        <> int.to_string(schema_check_attempts)
        <> "): "
        <> client.format_schema_check_error(error),
      )
      process.sleep(schema_check_delay_ms)
      check_schema_attempt(connection, expected, attempt + 1)
    }
    result -> result
  }
}
