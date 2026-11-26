//// Database Initialization
////
//// Sets up the PostgreSQL connection pool.
//// Note: Database migrations should be run separately (e.g., via `make migrate`)
//// before starting the application to avoid race conditions with multiple instances.
//// After the pool starts, the app checks that the schema is still the one
//// that dream_model generated the models from.

import dream_postgres/client.{
  type SchemaCheckError, type SchemaFingerprint, SchemaUnreadable, check_schema,
  format_schema_check_error,
}
import dream_postgres_client.{
  type Connection, ConnectionUnavailable, database, default_config, host,
  password, pool_size, port, start,
}
import gleam/erlang/process.{new_name, sleep}
import gleam/int.{to_string}
import gleam/io.{println_error}
import gleam/option.{Some}
import gleam/otp/actor.{Started}
import gleam/result
import models/post
import models/user

pub type DatabaseService {
  DatabaseService(connection: Connection)
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    default_config(pool_name: pool_name)
    |> host("localhost")
    |> port(5435)
    |> database("dream_example_database_db")
    |> dream_postgres_client.user("postgres")
    |> password(Some("postgres"))
    |> pool_size(10)

  // Start the connection pool
  use connection <- result.try(case start(config) {
    Ok(Started(_pid, connection)) -> Ok(connection)
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  })

  // Wait for the database, then stop with a clear message when the schema
  // changed after dream_model generated the models
  use Nil <- result.try(
    check_schema_waiting_for_database(connection, [
      user.schema_fingerprint,
      post.schema_fingerprint,
    ])
    |> result.map_error(format_schema_check_error),
  )
  Ok(DatabaseService(connection: connection))
}

/// How long the app runs the schema check again while the database cannot
/// be reached, in milliseconds. The last check can start just before this
/// deadline, and a failed check takes 2 to 3 seconds, the time that the
/// pool waits for a connection.
const schema_check_deadline_ms = 30_000

/// The time between two schema checks, in milliseconds
const schema_check_delay_ms = 2000

/// Runs `client.check_schema`, and waits for a database that cannot be
/// reached yet. When the pool has no connection, it prints one line, waits
/// `schema_check_delay_ms` and runs the check again, until
/// `schema_check_deadline_ms` passed since the first check. A changed
/// schema and the other database errors give the error at once.
pub fn check_schema_waiting_for_database(
  connection: Connection,
  expected: List(SchemaFingerprint),
) -> Result(Nil, SchemaCheckError) {
  check_schema_until(connection, expected, monotonic_time(Millisecond))
}

fn check_schema_until(
  connection: Connection,
  expected: List(SchemaFingerprint),
  started_ms: Int,
) -> Result(Nil, SchemaCheckError) {
  let result = check_schema(connection, expected)
  let elapsed_ms = monotonic_time(Millisecond) - started_ms
  case result {
    Error(SchemaUnreadable(error: ConnectionUnavailable, ..) as error)
      if elapsed_ms + schema_check_delay_ms < schema_check_deadline_ms
    -> {
      println_error(
        "Waiting for the database ("
        <> to_string(elapsed_ms / 1000)
        <> "s of "
        <> to_string(schema_check_deadline_ms / 1000)
        <> "s): "
        <> format_schema_check_error(error),
      )
      sleep(schema_check_delay_ms)
      check_schema_until(connection, expected, started_ms)
    }
    _ -> result
  }
}

/// The unit of `monotonic_time`. Erlang reads it as the atom `millisecond`.
type TimeUnit {
  Millisecond
}

/// The time of a clock that never goes back, for durations
@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: TimeUnit) -> Int
