//// Services - external dependencies

import dream_postgres/client as postgres
import envoy

pub type Services {
  Services(db: postgres.Connection)
}

/// Initialize services
pub fn initialize() -> Services {
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  let db = postgres.from_url(database_url)

  Services(db: db)
}

