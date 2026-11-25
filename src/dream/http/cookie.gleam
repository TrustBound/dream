//// HTTP cookie types and utilities
////
//// Guide: [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
////
//// Types and functions for working with HTTP cookies. Cookies can be used
//// with both requests and responses.
////
//// ## Quick Start
////
//// ### Create and read cookies <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_cookie_module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/cookie.{type Cookie}
//// import dream/http/request.{type Request}
//// import gleam/option.{None, Some}
////
//// pub fn new_cookies() -> List(Cookie) {
////   [
////     // Simple cookie
////     cookie.simple_cookie("theme", "dark"),
////     // Secure cookie (recommended for sensitive data)
////     cookie.secure_cookie("session_id", "abc123"),
////   ]
//// }
////
//// pub fn session_status(request: Request) -> String {
////   // Get cookie from request
////   case cookie.get_cookie_value(request.cookies, "session_id") {
////     Some(id) -> "Session " <> id
////     None -> "No session cookie"
////   }
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
/// ### Set SameSite <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_cookie_same_site.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie, Cookie, Lax}
/// import gleam/option
///
/// pub fn session_cookie() -> Cookie {
///   Cookie(
///     ..cookie.secure_cookie("session", "abc123"),
///     same_site: option.Some(Lax),
///   )
/// }
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
/// - `expires`: Expiration as Unix timestamp (seconds since epoch). The
///   `Set-Cookie` header writes it as an HTTP date in UTC, for example
///   `Expires=Tue, 14 Nov 2023 22:13:20 GMT`
/// - `max_age`: Lifetime in seconds from now
/// - `domain`: Domain where cookie is valid (defaults to current domain)
/// - `path`: Path where cookie is valid (defaults to current path)
/// - `secure`: Only send over HTTPS if True
/// - `http_only`: Not accessible to JavaScript if True (XSS protection)
/// - `same_site`: Controls cross-site request behavior
///
/// ## Example
///
/// ### Build or construct a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_cookie_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie, Cookie, Strict}
/// import gleam/option
///
/// pub fn builder_cookie() -> Cookie {
///   // Using builder (recommended)
///   cookie.secure_cookie("auth_token", "xyz789")
/// }
///
/// pub fn manual_cookie() -> Cookie {
///   // Constructing manually
///   Cookie(
///     name: "auth_token",
///     value: "xyz789",
///     expires: option.None,
///     // 1 hour
///     max_age: option.Some(3600),
///     domain: option.None,
///     path: option.Some("/"),
///     secure: True,
///     http_only: True,
///     same_site: option.Some(Strict),
///   )
/// }
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
/// ### Get the name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_cookie_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie
///
/// pub fn session_cookie_name() -> String {
///   let session_cookie = cookie.simple_cookie("session_id", "abc123")
///   // Returns "session_id"
///   cookie.cookie_name(session_cookie)
/// }
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
/// ### Get the value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_cookie_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie
///
/// pub fn session_cookie_value() -> String {
///   let session_cookie = cookie.simple_cookie("session_id", "abc123")
///   // Returns "abc123"
///   cookie.cookie_value(session_cookie)
/// }
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
/// ### Preference cookies <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_simple_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie}
///
/// pub fn preference_cookies() -> List(Cookie) {
///   [
///     // User preference cookie
///     cookie.simple_cookie("theme", "dark"),
///     // Language preference
///     cookie.simple_cookie("lang", "en"),
///   ]
/// }
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
/// ### Cookies for sensitive data <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_secure_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie}
///
/// pub fn login_cookies(
///   session_id: String,
///   jwt_token: String,
///   csrf_token: String,
/// ) -> List(Cookie) {
///   [
///     // Session cookie
///     cookie.secure_cookie("session_id", session_id),
///     // Authentication token
///     cookie.secure_cookie("auth_token", jwt_token),
///     // CSRF token
///     cookie.secure_cookie("csrf_token", csrf_token),
///   ]
/// }
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
/// ### Find a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_get_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie}
/// import gleam/option.{type Option, None, Some}
///
/// pub fn example_cookies() -> List(Cookie) {
///   [
///     cookie.simple_cookie("theme", "dark"),
///     cookie.secure_cookie("session_id", "abc123"),
///   ]
/// }
///
/// pub fn session_value(cookies: List(Cookie)) -> String {
///   case cookie.get_cookie(cookies, "session_id") {
///     // "abc123"
///     Some(session_cookie) -> cookie.cookie_value(session_cookie)
///     None -> "no session"
///   }
/// }
///
/// pub fn theme_cookie(cookies: List(Cookie)) -> Option(Cookie) {
///   // Case-insensitive: Some(Cookie("theme", "dark", ...))
///   cookie.get_cookie(cookies, "THEME")
/// }
/// ```
pub fn get_cookie(
  cookies: List(Cookie),
  name: String,
) -> option.Option(Cookie) {
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
/// ### Find a cookie value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_get_cookie_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie
/// import gleam/option.{type Option}
///
/// pub fn lookups() -> #(Option(String), Option(String)) {
///   let cookies = [
///     cookie.simple_cookie("theme", "dark"),
///     cookie.secure_cookie("session_id", "abc123"),
///   ]
///
///   // Some("dark")
///   let theme = cookie.get_cookie_value(cookies, "theme")
///   // None
///   let missing = cookie.get_cookie_value(cookies, "missing")
///   #(theme, missing)
/// }
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
/// ### Replace and add cookies <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_set_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie}
///
/// pub fn updated_cookies() -> List(Cookie) {
///   let cookies = [cookie.simple_cookie("theme", "light")]
///
///   // Replace existing cookie
///   let updated =
///     cookie.set_cookie(cookies, cookie.simple_cookie("theme", "dark"))
///   // Result: [Cookie("theme", "dark", ...)]
///
///   // Add new cookie
///   let with_session =
///     cookie.set_cookie(updated, cookie.secure_cookie("session_id", "abc123"))
///   // Result: [
///   //   Cookie("session_id", "abc123", ...),
///   //   Cookie("theme", "dark", ...)
///   // ]
///   with_session
/// }
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
  kept_cookies: List(Cookie),
) -> List(Cookie) {
  case cookies {
    [] -> list.reverse(kept_cookies)
    [cookie, ..rest] -> {
      let cookie_normalized = string.lowercase(cookie_name(cookie))
      let should_keep = cookie_normalized != normalized_name
      case should_keep {
        True ->
          filter_cookies_recursive(rest, normalized_name, [
            cookie,
            ..kept_cookies
          ])
        False -> filter_cookies_recursive(rest, normalized_name, kept_cookies)
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
/// ### Remove or expire a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_remove_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/cookie.{type Cookie, Cookie}
/// import gleam/option
///
/// pub fn without_theme() -> List(Cookie) {
///   let cookies = [
///     cookie.simple_cookie("theme", "dark"),
///     cookie.secure_cookie("session_id", "abc123"),
///   ]
///
///   // Remove theme cookie from list
///   cookie.remove_cookie(cookies, "theme")
///   // Result: [Cookie("session_id", "abc123", ...)]
/// }
///
/// pub fn expired_session() -> Cookie {
///   // To delete in browser, set expired cookie:
///   Cookie(
///     ..cookie.secure_cookie("session_id", ""),
///     // Expire immediately
///     max_age: option.Some(0),
///   )
/// }
/// ```
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie) {
  let normalized_name = string.lowercase(name)
  filter_matching_cookies(cookies, normalized_name)
}
