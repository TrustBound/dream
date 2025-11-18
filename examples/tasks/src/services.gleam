//// Services - external dependencies

import config.{type Config}
import gleam/erlang/process
import gleam/io
import gleam/option
import gleam/otp/actor
import pog

pub type Services {
  Services(db: pog.Connection)
}

/// Initialize services with config
pub fn initialize(cfg: Config) -> Services {
  io.println("Connecting to database: " <> cfg.database_url)

  // Use direct pog configuration like other examples
  let pool_name = process.new_name("tasks_postgres_pool")

  let config =
    pog.default_config(pool_name: pool_name)
    |> pog.host("localhost")
    |> pog.port(5437)
    |> pog.database("tasks_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)

  let assert Ok(actor.Started(_pid, connection)) = pog.start(config)

  io.println("Database connection pool started")
  Services(db: connection)
}
