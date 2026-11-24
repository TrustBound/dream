import config.{type Config}
import dream_postgres_client
import services/database

pub type Services {
  Services(db: dream_postgres_client.Connection)
}

/// Initialize services with config
pub fn initialize(_cfg: Config) -> Services {
  let db = database.initialize()
  Services(db: db)
}
