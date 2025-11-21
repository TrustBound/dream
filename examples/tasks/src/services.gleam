import config.{type Config}
import pog
import services/database

pub type Services {
  Services(db: pog.Connection)
}

/// Initialize services with config
pub fn initialize(_cfg: Config) -> Services {
  let db = database.initialize()
  Services(db: db)
}
