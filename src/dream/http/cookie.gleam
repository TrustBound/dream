//// HTTP cookie types and utilities
////
//// Types and functions for working with HTTP cookies. Cookies can be used
//// with both requests and responses.
////
//// ## Quick Start
////
//// ```gleam
//// import dream/http/cookie
////
//// // Simple cookie
//// cookie.simple_cookie("session_id", "abc123")
////
//// // Secure cookie (recommended for sensitive data)
//// cookie.secure_cookie("auth_token", "xyz789")
////
//// // Get cookie from request
//// case cookie.get_cookie_value(request.cookies, "session_id") {
////   Some(id) -> // Use the session ID
////   None -> // No session cookie
//// }
//// ```
////
//// ## Security
////
//// For sensitive data (sessions, auth tokens), always use `secure_cookie()` which sets:
//// - `secure=True`: Only sent over HTTPS
//// - `httpOnly=True`: Not accessible to JavaScript (XSS protection)
//// - `sameSite=Strict`: Prevents CSRF attacks

import gleam/list
import gleam/option
import gleam/string

/// SameSite cookie attribute
///
/// Controls when cookies are sent with cross-site requests.
///
/// - `Strict`: Cookie never sent with cross-site requests (most secure, may affect UX)
/// - `Lax`: Cookie sent with top-level navigations (good balance of security and UX)
/// - `None`: Cookie sent with all requests (requires `secure=True`)
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie.{Cookie, Strict}
/// import gleam/option
///
/// Cookie(
///   name: "session",
///   value: "abc123",
///   same_site: option.Some(Strict),
///   // ... other fields
/// )
/// ```
pub type SameSite {
  Strict
  Lax
  None
}

/// HTTP cookie type
///
/// Represents an HTTP cookie with all standard attributes.
/// Use `simple_cookie()` or `secure_cookie()` to create cookies
/// rather than constructing this directly.
///
/// ## Fields
///
/// - `name`: Cookie name (case-sensitive)
/// - `value`: Cookie value
/// - `expires`: Expiration as Unix timestamp (seconds since epoch)
/// - `max_age`: Lifetime in seconds from now
/// - `domain`: Domain where cookie is valid (defaults to current domain)
/// - `path`: Path where cookie is valid (defaults to current path)
/// - `secure`: Only send over HTTPS if True
/// - `http_only`: Not accessible to JavaScript if True (XSS protection)
/// - `same_site`: Controls cross-site request behavior
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie.{Cookie, Strict}
/// import gleam/option
///
/// // Using builder (recommended)
/// cookie.secure_cookie("auth_token", "xyz789")
///
/// // Constructing manually
/// Cookie(
///   name: "auth_token",
///   value: "xyz789",
///   expires: option.None,
///   max_age: option.Some(3600),  // 1 hour
///   domain: option.None,
///   path: option.Some("/"),
///   secure: True,
///   http_only: True,
///   same_site: option.Some(Strict),
/// )
/// ```
pub type Cookie {
  Cookie(
    name: String,
    value: String,
    expires: option.Option(Int),
    // Unix timestamp
    max_age: option.Option(Int),
    // Seconds
    domain: option.Option(String),
    path: option.Option(String),
    secure: Bool,
    http_only: Bool,
    same_site: option.Option(SameSite),
  )
}

/// Get the name of a cookie
///
/// Extracts the name field from a Cookie.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let c = cookie.simple_cookie("session_id", "abc123")
/// cookie.cookie_name(c)  // "session_id"
/// ```
pub fn cookie_name(cookie: Cookie) -> String {
  let Cookie(name, _, _, _, _, _, _, _, _) = cookie
  name
}

/// Get the value of a cookie
///
/// Extracts the value field from a Cookie.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let c = cookie.simple_cookie("session_id", "abc123")
/// cookie.cookie_value(c)  // "abc123"
/// ```
pub fn cookie_value(cookie: Cookie) -> String {
  let Cookie(_, value, _, _, _, _, _, _, _) = cookie
  value
}

/// Create a simple cookie with just name and value
///
/// Creates an unsecured cookie with no expiration or security flags.
/// **Not recommended for sensitive data** - use `secure_cookie()` instead
/// for sessions, auth tokens, or any sensitive information.
///
/// Use simple cookies for:
/// - User preferences (theme, language)
/// - Non-sensitive UI state
/// - Analytics tracking IDs
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// // User preference cookie
/// cookie.simple_cookie("theme", "dark")
///
/// // Language preference
/// cookie.simple_cookie("lang", "en")
/// ```
pub fn simple_cookie(name: String, value: String) -> Cookie {
  Cookie(
    name: name,
    value: value,
    expires: option.None,
    max_age: option.None,
    domain: option.None,
    path: option.None,
    secure: False,
    http_only: False,
    same_site: option.None,
  )
}

/// Create a secure cookie for sensitive data
///
/// Creates a cookie with security best practices enabled:
/// - `secure=True`: Only sent over HTTPS connections
/// - `httpOnly=True`: Not accessible to JavaScript (prevents XSS attacks)
/// - `sameSite=Strict`: Not sent with cross-site requests (prevents CSRF)
///
/// **Always use this for sensitive data** like session IDs, authentication tokens,
/// CSRF tokens, or any data that could be used to impersonate a user.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// // Session cookie
/// cookie.secure_cookie("session_id", generate_session_id())
///
/// // Authentication token
/// cookie.secure_cookie("auth_token", jwt_token)
///
/// // CSRF token
/// cookie.secure_cookie("csrf_token", generate_csrf_token())
/// ```
///
/// ## Security Note
///
/// The `httpOnly` flag prevents JavaScript from accessing the cookie,
/// which protects against XSS attacks where malicious scripts try to
/// steal session tokens.
pub fn secure_cookie(name: String, value: String) -> Cookie {
  Cookie(
    name: name,
    value: value,
    expires: option.None,
    max_age: option.None,
    domain: option.None,
    path: option.None,
    secure: True,
    http_only: True,
    same_site: option.Some(Strict),
  )
}

/// Get a cookie by name (case-insensitive)
///
/// Searches a list of cookies for one matching the given name.
/// Cookie name comparison is case-insensitive.
/// Returns the first matching cookie.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let cookies = [
///   cookie.simple_cookie("theme", "dark"),
///   cookie.secure_cookie("session_id", "abc123"),
/// ]
///
/// case cookie.get_cookie(cookies, "session_id") {
///   Some(c) -> cookie.cookie_value(c)  // "abc123"
///   None -> "no session"
/// }
///
/// // Case-insensitive
/// cookie.get_cookie(cookies, "THEME")  // Some(Cookie("theme", "dark", ...))
/// ```
pub fn get_cookie(cookies: List(Cookie), name: String) -> option.Option(Cookie) {
  let normalized_name = string.lowercase(name)
  find_cookie(cookies, normalized_name)
}

fn find_cookie(
  cookies: List(Cookie),
  normalized_name: String,
) -> option.Option(Cookie) {
  case cookies {
    [] -> option.None
    [cookie, ..rest] -> {
      let cookie_normalized = string.lowercase(cookie_name(cookie))
      let matches = cookie_normalized == normalized_name
      case matches {
        True -> option.Some(cookie)
        False -> find_cookie(rest, normalized_name)
      }
    }
  }
}

/// Get a cookie value by name
///
/// Convenience function that searches for a cookie and returns just its value.
/// Returns None if the cookie doesn't exist.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let cookies = [
///   cookie.simple_cookie("theme", "dark"),
///   cookie.secure_cookie("session_id", "abc123"),
/// ]
///
/// cookie.get_cookie_value(cookies, "theme")  // Some("dark")
/// cookie.get_cookie_value(cookies, "missing")  // None
/// ```
pub fn get_cookie_value(
  cookies: List(Cookie),
  name: String,
) -> option.Option(String) {
  case get_cookie(cookies, name) {
    option.Some(cookie) -> option.Some(cookie_value(cookie))
    option.None -> option.None
  }
}

/// Set or replace a cookie
///
/// If a cookie with this name exists (case-insensitive), replaces it.
/// If not, adds a new cookie. Only one cookie with the given name will
/// exist in the result.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let cookies = [cookie.simple_cookie("theme", "light")]
///
/// // Replace existing cookie
/// let updated = cookie.set_cookie(
///   cookies,
///   cookie.simple_cookie("theme", "dark")
/// )
/// // Result: [Cookie("theme", "dark", ...)]
///
/// // Add new cookie
/// let with_session = cookie.set_cookie(
///   updated,
///   cookie.secure_cookie("session_id", "abc123")
/// )
/// // Result: [
/// //   Cookie("session_id", "abc123", ...),
/// //   Cookie("theme", "dark", ...)
/// // ]
/// ```
pub fn set_cookie(cookies: List(Cookie), cookie: Cookie) -> List(Cookie) {
  let normalized_name = string.lowercase(cookie_name(cookie))
  let filtered = filter_matching_cookies(cookies, normalized_name)
  [cookie, ..filtered]
}

fn filter_matching_cookies(
  cookies: List(Cookie),
  normalized_name: String,
) -> List(Cookie) {
  filter_cookies_recursive(cookies, normalized_name, [])
}

fn filter_cookies_recursive(
  cookies: List(Cookie),
  normalized_name: String,
  acc: List(Cookie),
) -> List(Cookie) {
  case cookies {
    [] -> list.reverse(acc)
    [cookie, ..rest] -> {
      let cookie_normalized = string.lowercase(cookie_name(cookie))
      let should_keep = cookie_normalized != normalized_name
      case should_keep {
        True -> filter_cookies_recursive(rest, normalized_name, [cookie, ..acc])
        False -> filter_cookies_recursive(rest, normalized_name, acc)
      }
    }
  }
}

/// Remove a cookie by name (case-insensitive)
///
/// Removes all cookies with the given name (case-insensitive).
/// Returns a new list with matching cookies filtered out.
///
/// To delete a cookie in the browser, you typically need to set it with
/// an expired date or max-age=0, not just remove it from the list.
///
/// ## Example
///
/// ```gleam
/// import dream/http/cookie
///
/// let cookies = [
///   cookie.simple_cookie("theme", "dark"),
///   cookie.secure_cookie("session_id", "abc123"),
/// ]
///
/// // Remove theme cookie from list
/// let filtered = cookie.remove_cookie(cookies, "theme")
/// // Result: [Cookie("session_id", "abc123", ...)]
///
/// // To delete in browser, set expired cookie:
/// let expired = Cookie(
///   name: "session_id",
///   value: "",
///   max_age: option.Some(0),  // Expire immediately
///   // ... other fields
/// )
/// ```
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie) {
  let normalized_name = string.lowercase(name)
  filter_matching_cookies(cookies, normalized_name)
}
