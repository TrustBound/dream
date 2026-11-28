//// The services of the lists app: the connection to PostgreSQL.

import dream_postgres/client as postgres
import dream_postgres_client.{type Connection}
import envoy
import gleam/result
import gleam/string

pub type Services {
  Services(database: Connection)
}

/// The services of the running app: a pool of connections to the
/// database at `DATABASE_URL`.
pub fn initialize_services() -> Result(Services, String) {
  use url <- result.try(
    envoy.get("DATABASE_URL")
    |> result.replace_error("Set DATABASE_URL to the URL of the database"),
  )
  use database <- result.try(
    postgres.from_url(url) |> result.map_error(string.inspect),
  )
  Ok(Services(database:))
}
