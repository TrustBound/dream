//// HTTP status code constants
////
//// Simple Int constants for common HTTP status codes.
//// Use these for semantic clarity in your responses instead of magic numbers.
////
//// ## Example
////
//// ```gleam
//// import dream/http/status
//// import dream/http/response
////
//// pub fn index(request, context, services) {
////   response.text_response(status.ok, "Hello, World!")
//// }
//// ```

// 2xx Success

/// 200 OK - Request succeeded
///
/// The request succeeded. The meaning depends on the HTTP method:
/// - GET: Resource fetched and transmitted in response body
/// - POST: Resource created or action completed, result in response body
/// - PUT/PATCH: Resource updated successfully
pub const ok = 200

/// 201 Created - New resource created successfully
///
/// Request succeeded and new resource was created. Typically used with POST
/// requests. Location header often included with URI of new resource.
pub const created = 201

/// 202 Accepted - Request accepted for processing
///
/// Request accepted but processing not complete. Used for asynchronous operations
/// where the result will be available later.
pub const accepted = 202

/// 204 No Content - Success with no response body
///
/// Request succeeded but no content to return. Commonly used for DELETE requests
/// or PUT requests where no response body is needed.
pub const no_content = 204

// 3xx Redirection

/// 301 Moved Permanently - Resource permanently moved to new URL
///
/// Resource has permanently moved to a new URI. Clients should use the new URI
/// for all future requests. Location header contains new URI.
pub const moved_permanently = 301

/// 302 Found - Temporary redirect
///
/// Resource temporarily at different URI. Client should continue using original
/// URI for future requests. Location header contains temporary URI.
pub const found = 302

/// 303 See Other - Redirect to GET after POST
///
/// Response to POST/PUT/DELETE can be found at another URI using GET.
/// Prevents duplicate submissions when refreshing after form submission.
pub const see_other = 303

/// 307 Temporary Redirect - Temporary redirect preserving method
///
/// Like 302 but requires client to use same HTTP method on redirected request.
/// More strict than 302 about preserving the original request method.
pub const temporary_redirect = 307

// 4xx Client Errors

/// 400 Bad Request - Invalid request syntax or parameters
///
/// Server cannot process request due to client error: malformed syntax,
/// invalid parameters, missing required fields, or invalid JSON.
pub const bad_request = 400

/// 401 Unauthorized - Authentication required
///
/// Request requires authentication. Client must provide valid credentials.
/// Despite the name, this really means "unauthenticated".
pub const unauthorized = 401

/// 403 Forbidden - Authenticated but not authorized
///
/// Server understood request but refuses to authorize it. Authentication
/// won't help - user doesn't have permission for this resource.
pub const forbidden = 403

/// 404 Not Found - Resource doesn't exist
///
/// Server can't find requested resource. Also used to hide existence of
/// resources the client shouldn't know about (instead of 403).
pub const not_found = 404

/// 405 Method Not Allowed - HTTP method not supported
///
/// Request method is known but not supported for this resource.
/// Allow header should list valid methods.
pub const method_not_allowed = 405

/// 409 Conflict - Request conflicts with current state
///
/// Request conflicts with current server state. Common with concurrent
/// updates, version conflicts, or duplicate resource creation.
pub const conflict = 409

/// 422 Unprocessable Content - Semantic validation failed
///
/// Request was well-formed but contains semantic errors. The data is valid
/// syntax but fails business logic validation (e.g., invalid email format,
/// date in past, etc.).
pub const unprocessable_content = 422

/// 429 Too Many Requests - Rate limit exceeded
///
/// Client has sent too many requests in given time. Used for rate limiting.
/// Retry-After header may indicate when to retry.
pub const too_many_requests = 429

// 5xx Server Errors

/// 500 Internal Server Error - Unexpected server error
///
/// Server encountered unexpected condition preventing request fulfillment.
/// Generic error when no more specific error is suitable.
pub const internal_server_error = 500

/// 501 Not Implemented - Method not supported
///
/// Server doesn't support functionality required to fulfill request.
/// Method not recognized or not implemented by server.
pub const not_implemented = 501

/// 503 Service Unavailable - Server temporarily unavailable
///
/// Server temporarily unable to handle request due to overload or maintenance.
/// Retry-After header may indicate when to retry.
pub const service_unavailable = 503
