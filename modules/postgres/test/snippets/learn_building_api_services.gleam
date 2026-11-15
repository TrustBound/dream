//// Lesson 2: Services holding the database connection pool
//// (src/services.gleam)

import gleam/erlang/process
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import pog

pub type Services {
  Services(db: pog.Connection)
}

pub fn initialize_services() -> Result(Services, actor.StartError) {
  create_database_config()
  |> pog.start()
  |> result.map(fn(started) { Services(db: started.data) })
}

pub fn create_database_config() -> pog.Config {
  pog.default_config(pool_name: process.new_name("db_pool"))
  |> pog.host("localhost")
  |> pog.port(5432)
  |> pog.database("myapp")
  |> pog.user("postgres")
  |> pog.password(Some("postgres"))
  |> pog.pool_size(10)
}
