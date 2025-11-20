//// Dream unified error type
////
//// A single error type used throughout Dream applications for both
//// HTTP-level validation errors and domain-level operation errors.
//// This eliminates the need for error conversion between layers.
////
//// ## Philosophy
////
//// Instead of having separate error types for HTTP validation, database operations,
//// and business logic, Dream uses one unified Error type. This means you can return
//// errors from any layer without conversion, and the type system tracks them naturally.
////
//// ## Usage
////
//// Return errors from controllers, models, or operations using the same type:
////
//// ```gleam
//// import dream/http/error.{type Error, BadRequest, NotFound}
//// import gleam/result
////
//// pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
////   case query_user(db, id) {
////     Ok(user) -> Ok(user)
////     Error(Nil) -> Error(NotFound("User not found"))
////   }
//// }
////
//// pub fn create_user(db: Connection, name: String) -> Result(User, Error) {
////   case validate_name(name) {
////     False -> Error(BadRequest("Name must not be empty"))
////     True -> insert_user(db, name)
////   }
//// }
//// ```
////
//// ## Converting to Responses
////
//// Use `to_status_code()` and `message()` to convert errors to HTTP responses:
////
//// ```gleam
//// import dream/http/error
//// import dream/http/response
//// import gleam/json
////
//// case get_user(db, id) {
////   Ok(user) -> 
////     response.json_response(200, user_to_json(user))
////   Error(err) -> 
////     response.json_response(
////       error.to_status_code(err),
////       json.object([#("error", json.string(error.message(err)))])
////     )
//// }
//// ```

/// Unified error type for Dream applications
///
/// Maps semantic error types to HTTP status codes. Each variant includes
/// a message string for context-specific error details.
///
/// ## Variants
///
/// - `BadRequest`: Client sent invalid data (malformed, missing required fields)
/// - `Unauthorized`: Authentication is required but not provided
/// - `Forbidden`: Authenticated but lacks permission for this action
/// - `NotFound`: Requested resource doesn't exist
/// - `UnprocessableContent`: Valid syntax but fails business logic validation
/// - `InternalServerError`: Unexpected server error (database, external API, etc.)
pub type Error {
  /// 400 Bad Request - Invalid or missing parameter, validation failure
  ///
  /// Use when client sends malformed data, missing required fields,
  /// or syntactically invalid input (e.g., "abc" when expecting integer).
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(BadRequest("Field 'email' is required"))
  /// Error(BadRequest("ID must be a positive integer"))
  /// ```
  BadRequest(String)

  /// 401 Unauthorized - Authentication required
  ///
  /// Use when request requires valid authentication credentials.
  /// Despite the name, this means "not authenticated" (no valid credentials).
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(Unauthorized("Authentication token required"))
  /// Error(Unauthorized("Invalid or expired token"))
  /// ```
  Unauthorized(String)

  /// 403 Forbidden - Authenticated but not authorized
  ///
  /// Use when user is authenticated but lacks permission for this action.
  /// Unlike Unauthorized, providing credentials won't help.
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(Forbidden("Admin access required"))
  /// Error(Forbidden("Cannot delete another user's post"))
  /// ```
  Forbidden(String)

  /// 404 Not Found - Resource doesn't exist
  ///
  /// Use when requested resource doesn't exist or user shouldn't
  /// know it exists (to hide existence instead of returning 403).
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(NotFound("User not found"))
  /// Error(NotFound("Post with ID 123 does not exist"))
  /// ```
  NotFound(String)

  /// 422 Unprocessable Content - Semantic validation failed
  ///
  /// Use when request is syntactically valid but fails business logic
  /// validation (e.g., date in past, email already taken, invalid state).
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(UnprocessableContent("Email already registered"))
  /// Error(UnprocessableContent("Start date must be before end date"))
  /// ```
  UnprocessableContent(String)

  /// 500 Internal Server Error - Unexpected error (database, external service, etc)
  ///
  /// Use for unexpected server errors: database failures, external API errors,
  /// filesystem errors, etc. Should be logged for investigation.
  ///
  /// ## Example
  ///
  /// ```gleam
  /// Error(InternalServerError("Database connection failed"))
  /// Error(InternalServerError("External payment API unavailable"))
  /// ```
  InternalServerError(String)
}

/// Convert Error to HTTP status code
///
/// Maps each error variant to its corresponding HTTP status code.
/// Use this when building HTTP responses from errors.
///
/// ## Example
///
/// ```gleam
/// import dream/http/error.{type Error, NotFound}
/// import dream/http/response
///
/// let err = NotFound("User not found")
/// let status = error.to_status_code(err)  // Returns 404
/// response.json_response(status, error_json(err))
/// ```
pub fn to_status_code(error: Error) -> Int {
  case error {
    BadRequest(_) -> 400
    Unauthorized(_) -> 401
    Forbidden(_) -> 403
    NotFound(_) -> 404
    UnprocessableContent(_) -> 422
    InternalServerError(_) -> 500
  }
}

/// Extract the error message from an Error
///
/// Returns the message string from any error variant.
/// Useful when building error responses or logging.
///
/// ## Example
///
/// ```gleam
/// import dream/http/error.{type Error, BadRequest}
/// import gleam/json
///
/// let err = BadRequest("Invalid email format")
/// let msg = error.message(err)  // Returns "Invalid email format"
///
/// // Build JSON error response
/// json.object([
///   #("error", json.string(msg)),
///   #("status", json.int(error.to_status_code(err)))
/// ])
/// ```
pub fn message(error: Error) -> String {
  case error {
    BadRequest(msg) -> msg
    Unauthorized(msg) -> msg
    Forbidden(msg) -> msg
    NotFound(msg) -> msg
    UnprocessableContent(msg) -> msg
    InternalServerError(msg) -> msg
  }
}
