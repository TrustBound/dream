//// # Mock server config types
////
//// Types for configuring the mock server at startup when using config mode.
//// Pass a list of `MockRoute` to `server.start_with_config(port, config)` to define
//// path → (status, body) mappings. The mock has no built-in provider logic;
//// the caller supplies all routes.

import dream/http/request.{type Method}
import gleam/option

/// How to match the request path against a route's path.
///
/// Use `Exact` when you want one concrete path, and `Prefix` when a route
/// should cover a path family (for example `/api` matching `/api/v1/users`).
pub type PathMatch {
  /// Request path must equal the route path exactly.
  Exact
  /// Request path must start with the route path (e.g. "/api" matches "/api/v1").
  Prefix
}

/// One response rule used by `server.start_with_config`.
///
/// When a request matches this route's path (and optional method), the mock
/// returns the configured status and body exactly as provided.
///
/// First matching entry in the config list wins. Put more specific routes before
/// broader prefix routes if you want them to take precedence.
///
/// ## Fields
///
/// - `path`: Path to match, such as `"/v1/chat/completions"`.
/// - `path_match`: `Exact` or `Prefix`.
/// - `method`: `Some(Method)` to restrict by method, or `None` to match any.
/// - `status`: HTTP status code to return.
/// - `body`: Response body string to return (JSON, text, or any payload).
pub type MockRoute {
  MockRoute(
    path: String,
    path_match: PathMatch,
    method: option.Option(Method),
    status: Int,
    body: String,
  )
}

/// Context used internally when the server is started in config mode.
///
/// It holds the route list consumed by the config router/controller.
pub type MockConfigContext {
  MockConfigContext(routes: List(MockRoute))
}
