//// Database Services
////
//// Application-specific services for the database example

import dream/services/service.{type DatabaseService}
import examples/database/database

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
/// Uses assert to panic if initialization fails - adjust for production use
pub fn initialize_services() -> Services {
  let assert Ok(database_service) = database.init_database()
  Services(database: database_service)
}
