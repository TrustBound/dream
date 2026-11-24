import dream_postgres_client
import gleam/erlang/process
import gleam/io
import gleam/option
import gleam/otp/actor

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
  connection
}
