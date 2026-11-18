//// README: Or from URL
////
//// Reads a connection URL into a config, and starts the connection pool
//// from a URL. Both return a Result, so a bad URL is a value you handle.

import dream_postgres/client as postgres
import gleam/erlang/process
import gleam/string

pub fn describe_url(url: String) -> String {
  let pool_name = process.new_name("db_pool")
  case postgres.parse_config(pool_name, url) {
    Ok(config) -> "Database " <> config.database <> " on " <> config.host
    Error(postgres.UnsupportedParameter(name)) ->
      "Unsupported parameter: " <> name
    Error(error) -> "Invalid URL: " <> string.inspect(error)
  }
}

pub fn connect_from_url() -> Result(postgres.Connection, postgres.FromUrlError) {
  postgres.from_url("postgresql://user:pass@localhost:5432/myapp")
}
