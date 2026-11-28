//// README: Connection Builder Pattern
////
//// Builds a production connection config step by step and connects.

import dream_postgres/client as postgres
import gleam/erlang/process
import gleam/otp/actor

pub fn production_config() -> postgres.Config {
  let pool_name = process.new_name("my_db_pool")
  postgres.new(pool_name)
  |> postgres.host("localhost")
  |> postgres.port(5432)
  |> postgres.database("myapp_prod")
  |> postgres.user("postgres")
  |> postgres.password("secret")
  // Max 20 connections
  |> postgres.pool_size(20)
}

pub fn connect_production() -> Result(postgres.Connection, actor.StartError) {
  production_config()
  |> postgres.connect()
}
