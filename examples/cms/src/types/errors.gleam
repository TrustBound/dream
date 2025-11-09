//// Common error types for the CMS

pub type DataError {
  NotFound
  DatabaseError
  ValidationError(String)
  Unauthorized
}

