//// Starts the connection pool, then checks that the schema is still the
//// one that dream_model generated the models from.

import dream_postgres/client
import dream_postgres_client
import gleam/erlang/process
import gleam/int
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

  // Wait for the database, then stop with a clear message when the schema
  // changed after dream_model generated the models
  case
    check_schema_waiting_for_database(connection, [
      project.schema_fingerprint,
      tag.schema_fingerprint,
      task.schema_fingerprint,
    ])
  {
    Ok(Nil) -> connection
    Error(error) -> stop(client.format_schema_check_error(error))
  }
}

/// Prints the message on standard error and stops the app with exit
/// status 1, with no crash report
fn stop(message: String) -> a {
  io.println_error(message)
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a

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
