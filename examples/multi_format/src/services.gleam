//// Application services for multi-format example

import database.{type DatabaseService}

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
pub fn initialize_services() -> Services {
  let assert Ok(database_service) = database.init_database()
  Services(database: database_service)
}
