//// HTTP status code constants
////
//// Simple Int constants for common HTTP status codes.
//// Use these for semantic clarity in your responses.

// 2xx Success
pub const ok = 200

pub const created = 201

pub const accepted = 202

pub const no_content = 204

// 3xx Redirection
pub const moved_permanently = 301

pub const found = 302

pub const see_other = 303

pub const temporary_redirect = 307

// 4xx Client Errors
pub const bad_request = 400

pub const unauthorized = 401

pub const forbidden = 403

pub const not_found = 404

pub const method_not_allowed = 405

pub const conflict = 409

pub const unprocessable_content = 422

pub const too_many_requests = 429

// 5xx Server Errors
pub const internal_server_error = 500

pub const not_implemented = 501

pub const service_unavailable = 503

