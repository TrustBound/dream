//// Error types for the task application

pub type DataError {
  NotFound
  DatabaseError
  ValidationError(String)
}

