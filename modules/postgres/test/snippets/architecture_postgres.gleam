//// Architecture reference: dream_postgres
////
//// Builds a connection config, runs a query, and turns the result into a
//// value with query.first_row.

import dream_postgres/client.{
  type Config, type Connection, type QueryError, type Returned,
}
import dream_postgres/query
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/otp/actor
import pog

pub fn create_database_config() -> Config {
  client.new(process.new_name("app_database"))
  |> client.host("localhost")
  |> client.database("app")
  |> client.pool_size(10)
}

pub fn connect_database() -> Result(Connection, actor.StartError) {
  create_database_config()
  |> client.connect()
}

pub fn find_user_name(db: Connection, id: Int) -> String {
  pog.query("SELECT name FROM users WHERE id = $1")
  |> pog.parameter(pog.int(id))
  |> pog.returning(decode.at([0], decode.string))
  |> pog.execute(db)
  |> describe_user_name()
}

pub fn describe_user_name(
  result: Result(Returned(String), QueryError),
) -> String {
  case query.first_row(result) {
    Ok(name) -> name
    Error(query.NotFound) -> "No such user"
    Error(query.DatabaseError) -> "The database query failed"
  }
}
