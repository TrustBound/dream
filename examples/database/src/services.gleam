//// Database Services
////
//// Application-specific services for the database example

import database.{type DatabaseService}

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
/// Panics with the error message if initialization fails, for example when
/// the schema changed after dream_model generated the models
pub fn initialize_services() -> Services {
  case database.init_database() {
    Ok(database_service) -> Services(database: database_service)
    Error(message) -> panic as message
  }
}
