//// Application services for multi-format example

import database.{type DatabaseService}
import gleam/io.{println_error}

/// Application services
pub type Services {
  Services(database: DatabaseService)
}

/// Initialize all services
/// Stops the app with the error message if initialization fails, for
/// example when the database cannot be reached or the schema changed
/// after dream_model generated the models
pub fn initialize_services() -> Services {
  case database.init_database() {
    Ok(db_service) -> Services(database: db_service)
    Error(message) -> stop(message)
  }
}

/// Prints the message on standard error and stops the app with exit
/// status 1, with no crash report
fn stop(message: String) -> a {
  println_error(message)
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a
