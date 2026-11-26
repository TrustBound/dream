//// Dream unified error type
////
//// Guide: [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html).
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
//// Packages of the Dream ecosystem, such as dream_postgres, return the shared
//// error `dream_errors.Error(cause)`. `from_shared` converts it to an `Error`
//// with a generic text for the client.
////
//// ## Usage
////
//// Return errors from controllers, models, or operations using the same type:
////
//// ### Return errors from any layer <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/error.{type Error, BadRequest, NotFound}
//// import gleam/list
//// import gleam/result
////
//// pub type User {
////   User(id: Int, name: String)
//// }
////
//// pub fn get_user(users: List(User), id: Int) -> Result(User, Error) {
////   list.find(users, fn(user) { user.id == id })
////   |> result.replace_error(NotFound("User not found"))
//// }
////
//// pub fn create_user(users: List(User), name: String) -> Result(User, Error) {
////   case name {
////     "" -> Error(BadRequest("Name must not be empty"))
////     _ -> Ok(User(id: list.length(users) + 1, name: name))
////   }
//// }
//// ```
////
//// ## Converting to Responses
////
//// Use `to_status_code()` and `message()` to convert errors to HTTP responses:
////
//// ### Convert an error to a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/error.{type Error, message, to_status_code}
//// import dream/http/response.{type Response, json_response}
//// import gleam/json
////
//// pub fn user_response(result: Result(String, Error)) -> Response {
////   case result {
////     Ok(name) -> json_response(200, user_to_json(name))
////     Error(error) -> create_error_response(error)
////   }
//// }
////
//// fn user_to_json(name: String) -> String {
////   json.object([#("name", json.string(name))])
////   |> json.to_string
//// }
////
//// fn create_error_response(error: Error) -> Response {
////   let error_json = json.object([#("error", json.string(message(error)))])
////   json_response(to_status_code(error), json.to_string(error_json))
//// }
//// ```

import dream_errors.{Failed, Invalid, Timeout, Unavailable}

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
/// - `Conflict`: Request clashes with the current state of the resource
/// - `UnprocessableContent`: Valid syntax but fails business logic validation
/// - `InternalServerError`: Unexpected server error (database, external API, etc.)
/// - `ServiceUnavailable`: A service that the server needs is down or full
/// - `GatewayTimeout`: A service that the server called did not answer in time
pub type Error {
  /// 400 Bad Request - Invalid or missing parameter, validation failure
  ///
  /// Use when client sends malformed data, missing required fields,
  /// or syntactically invalid input (e.g., "abc" when expecting integer).
  ///
  /// ## Example
  ///
  /// ### Return BadRequest <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_bad_request.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, BadRequest}
  ///
  /// pub fn check_signup(email: String, id: Int) -> Result(Nil, Error) {
  ///   case email, id {
  ///     "", _ -> Error(BadRequest("Field 'email' is required"))
  ///     _, id if id < 1 -> Error(BadRequest("ID must be a positive integer"))
  ///     _, _ -> Ok(Nil)
  ///   }
  /// }
  /// ```
  BadRequest(String)

  /// 401 Unauthorized - Authentication required
  ///
  /// Use when request requires valid authentication credentials.
  /// Despite the name, this means "not authenticated" (no valid credentials).
  ///
  /// ## Example
  ///
  /// ### Return Unauthorized <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_unauthorized.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, Unauthorized}
  /// import gleam/list
  ///
  /// pub fn authenticate(
  ///   token: String,
  ///   valid_tokens: List(String),
  /// ) -> Result(String, Error) {
  ///   case token, list.contains(valid_tokens, token) {
  ///     "", _ -> Error(Unauthorized("Authentication token required"))
  ///     _, False -> Error(Unauthorized("Invalid or expired token"))
  ///     _, True -> Ok(token)
  ///   }
  /// }
  /// ```
  Unauthorized(String)

  /// 403 Forbidden - Authenticated but not authorized
  ///
  /// Use when user is authenticated but lacks permission for this action.
  /// Unlike Unauthorized, providing credentials won't help.
  ///
  /// ## Example
  ///
  /// ### Return Forbidden <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_forbidden.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, Forbidden}
  ///
  /// pub fn require_admin(is_admin: Bool) -> Result(Nil, Error) {
  ///   case is_admin {
  ///     True -> Ok(Nil)
  ///     False -> Error(Forbidden("Admin access required"))
  ///   }
  /// }
  ///
  /// pub fn check_post_owner(user_id: Int, author_id: Int) -> Result(Nil, Error) {
  ///   case user_id == author_id {
  ///     True -> Ok(Nil)
  ///     False -> Error(Forbidden("Cannot delete another user's post"))
  ///   }
  /// }
  /// ```
  Forbidden(String)

  /// 404 Not Found - Resource doesn't exist
  ///
  /// Use when requested resource doesn't exist or user shouldn't
  /// know it exists (to hide existence instead of returning 403).
  ///
  /// ## Example
  ///
  /// ### Return NotFound <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_not_found.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, NotFound}
  /// import gleam/int
  /// import gleam/list
  /// import gleam/result
  ///
  /// pub fn find_user(
  ///   users: List(#(Int, String)),
  ///   id: Int,
  /// ) -> Result(String, Error) {
  ///   list.key_find(users, id)
  ///   |> result.replace_error(NotFound("User not found"))
  /// }
  ///
  /// pub fn find_post(
  ///   posts: List(#(Int, String)),
  ///   id: Int,
  /// ) -> Result(String, Error) {
  ///   list.key_find(posts, id)
  ///   |> result.replace_error(NotFound(
  ///     "Post with ID " <> int.to_string(id) <> " does not exist",
  ///   ))
  /// }
  /// ```
  NotFound(String)

  /// 409 Conflict - Request clashes with the current state of the resource
  ///
  /// Use when the request is valid, but the current state of the resource
  /// stops it (e.g., a unique value that is already taken, an edit against
  /// a stale version, or a state change that the current state does not allow).
  ///
  /// ## Example
  ///
  /// ### Return Conflict <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_conflict.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, Conflict}
  /// import gleam/list
  ///
  /// pub fn check_email(
  ///   email: String,
  ///   registered: List(String),
  /// ) -> Result(String, Error) {
  ///   case list.contains(registered, email) {
  ///     True -> Error(Conflict("Email already registered"))
  ///     False -> Ok(email)
  ///   }
  /// }
  ///
  /// pub fn check_version(sent: Int, current: Int) -> Result(Nil, Error) {
  ///   case sent == current {
  ///     True -> Ok(Nil)
  ///     False -> Error(Conflict("The post changed after you loaded it"))
  ///   }
  /// }
  /// ```
  Conflict(String)

  /// 422 Unprocessable Content - Semantic validation failed
  ///
  /// Use when request is syntactically valid but fails business logic
  /// validation (e.g., a start date after the end date, a date in the past).
  ///
  /// ## Example
  ///
  /// ### Return UnprocessableContent <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_unprocessable_content.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, UnprocessableContent}
  ///
  /// pub fn check_dates(start_date: Int, end_date: Int) -> Result(Nil, Error) {
  ///   case start_date < end_date {
  ///     True -> Ok(Nil)
  ///     False -> Error(UnprocessableContent("Start date must be before end date"))
  ///   }
  /// }
  /// ```
  UnprocessableContent(String)

  /// 500 Internal Server Error - Unexpected error (database, external service, etc)
  ///
  /// Use for unexpected server errors: database failures, external API errors,
  /// filesystem errors, etc. Should be logged for investigation.
  ///
  /// ## Example
  ///
  /// ### Return InternalServerError <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_internal_server_error.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, InternalServerError}
  /// import gleam/result
  ///
  /// pub fn load_users(
  ///   query_result: Result(List(String), Nil),
  /// ) -> Result(List(String), Error) {
  ///   query_result
  ///   |> result.replace_error(InternalServerError("Database connection failed"))
  /// }
  ///
  /// pub fn charge(payment_result: Result(Int, Nil)) -> Result(Int, Error) {
  ///   payment_result
  ///   |> result.replace_error(InternalServerError(
  ///     "External payment API unavailable",
  ///   ))
  /// }
  /// ```
  InternalServerError(String)

  /// 503 Service Unavailable - A service that the server needs is down
  ///
  /// Use when the server cannot answer now because a service that it needs
  /// is down or has no free capacity: no database connection, a full pool,
  /// or a dependency in maintenance. The client can try again later.
  ///
  /// ## Example
  ///
  /// ### Return ServiceUnavailable <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_service_unavailable.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, ServiceUnavailable}
  /// import gleam/result.{replace_error}
  ///
  /// pub fn load_rates(cache_result: Result(Float, Nil)) -> Result(Float, Error) {
  ///   cache_result
  ///   |> replace_error(ServiceUnavailable("Rate service is down"))
  /// }
  /// ```
  ServiceUnavailable(String)

  /// 504 Gateway Timeout - A service that the server called did not answer
  ///
  /// Use when the server called a database or an external service, and the
  /// call did not finish in time.
  ///
  /// ## Example
  ///
  /// ### Return GatewayTimeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_gateway_timeout.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
  ///
  /// ```gleam
  /// import dream/http/error.{type Error, GatewayTimeout}
  /// import gleam/result.{replace_error}
  ///
  /// pub fn fetch_quote(
  ///   upstream_result: Result(String, Nil),
  /// ) -> Result(String, Error) {
  ///   upstream_result
  ///   |> replace_error(GatewayTimeout("Quote service did not answer"))
  /// }
  /// ```
  GatewayTimeout(String)
}

/// Convert Error to HTTP status code
///
/// Maps each error variant to its corresponding HTTP status code.
/// Use this when building HTTP responses from errors.
///
/// ## Example
///
/// ### Get the status code <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_to_status_code.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{NotFound}
/// import dream/http/response.{type Response}
/// import gleam/json
///
/// pub fn not_found_response() -> Response {
///   let not_found = NotFound("User not found")
///   // Returns 404
///   let status = error.to_status_code(not_found)
///   let error_json =
///     json.object([#("error", json.string(error.message(not_found)))])
///   response.json_response(status, json.to_string(error_json))
/// }
/// ```
pub fn to_status_code(error: Error) -> Int {
  case error {
    BadRequest(_) -> 400
    Unauthorized(_) -> 401
    Forbidden(_) -> 403
    NotFound(_) -> 404
    Conflict(_) -> 409
    UnprocessableContent(_) -> 422
    InternalServerError(_) -> 500
    ServiceUnavailable(_) -> 503
    GatewayTimeout(_) -> 504
  }
}

/// Extract the error message from an Error
///
/// Returns the message string from any error variant.
/// Useful when building error responses or logging.
///
/// ## Example
///
/// ### Get the message <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_error_message.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{BadRequest}
/// import gleam/json
///
/// pub fn bad_request_json() -> json.Json {
///   let bad_request = BadRequest("Invalid email format")
///   // Returns "Invalid email format"
///   let error_message = error.message(bad_request)
///
///   // Build JSON error response
///   json.object([
///     #("error", json.string(error_message)),
///     #("status", json.int(error.to_status_code(bad_request))),
///   ])
/// }
/// ```
pub fn message(error: Error) -> String {
  case error {
    BadRequest(message) -> message
    Unauthorized(message) -> message
    Forbidden(message) -> message
    NotFound(message) -> message
    Conflict(message) -> message
    UnprocessableContent(message) -> message
    InternalServerError(message) -> message
    ServiceUnavailable(message) -> message
    GatewayTimeout(message) -> message
  }
}

/// Convert the shared error of the Dream ecosystem to an HTTP error
///
/// Packages such as dream_postgres and the models of dream_model return
/// `dream_errors.Error(cause)`. This function gives each kind its status:
///
/// - `NotFound` gives `NotFound("Not found")`, a 404.
/// - `Conflict` gives `Conflict("Conflict")`, a 409.
/// - `Invalid` gives `UnprocessableContent("Invalid input")`, a 422.
/// - `Unavailable` gives `ServiceUnavailable("Service unavailable")`, a 503.
/// - `Timeout` gives `GatewayTimeout("Timed out")`, a 504.
/// - `Failed` gives `InternalServerError("Internal server error")`, a 500.
///
/// The text is a fixed, generic phrase. It is never the `message` of the
/// shared error. That message is for developers and logs: it can name
/// tables, constraints, hosts and values, and a client must not see it.
/// Log the shared error before you convert it, and match a case first when
/// the client needs a specific text, for example `User not found`.
///
/// ## Example
///
/// ### Give a missing profile its own text <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_from_shared.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error, NotFound, from_shared}
/// import dream_errors
///
/// pub type StoreError {
///   StoreDown
/// }
///
/// pub fn load_profile(
///   store_result: Result(String, dream_errors.Error(StoreError)),
/// ) -> Result(String, Error) {
///   case store_result {
///     Ok(profile) -> Ok(profile)
///     Error(dream_errors.NotFound(..)) -> Error(NotFound("Profile not found"))
///     Error(shared) -> Error(from_shared(shared))
///   }
/// }
/// ```
pub fn from_shared(error: dream_errors.Error(cause)) -> Error {
  case error {
    dream_errors.NotFound(..) -> NotFound("Not found")
    dream_errors.Conflict(..) -> Conflict("Conflict")
    Invalid(..) -> UnprocessableContent("Invalid input")
    Unavailable(..) -> ServiceUnavailable("Service unavailable")
    Timeout(..) -> GatewayTimeout("Timed out")
    Failed(..) -> InternalServerError("Internal server error")
  }
}
