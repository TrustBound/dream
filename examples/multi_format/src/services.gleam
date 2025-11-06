//// Application services for multi-format example

import dream/services/service.{type DatabaseService}
import database

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
pub fn initialize_services() -> Services {
  let assert Ok(database_service) = database.init_database()
  Services(database: database_service)
}
