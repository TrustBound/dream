//// Starts the connection pool, then checks that the schema is still the
//// one that dream_model generated the models from.

import dream_postgres/client.{
  type SchemaCheckError, type SchemaFingerprint, SchemaUnreadable, check_schema,
  format_schema_check_error,
}
import dream_postgres_client.{type Connection, ConnectionUnavailable}
import gleam/erlang/process.{sleep}
import gleam/int.{to_string}
import gleam/io.{println_error}
import gleam/option
import gleam/otp/actor
import models/project.{schema_fingerprint}
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

  // Wait for the database, then stop with a clear message when the schema
  // changed after dream_model generated the models
  case
    check_schema_waiting_for_database(connection, [
      schema_fingerprint,
      tag.schema_fingerprint,
      task.schema_fingerprint,
    ])
  {
    Ok(Nil) -> connection
    Error(error) -> stop(format_schema_check_error(error))
  }
}

/// Prints the message on standard error and stops the app with exit
/// status 1, with no crash report
fn stop(message: String) -> a {
  println_error(message)
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a

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
