//// HTTP cookie types and utilities
////
//// Types and functions for working with HTTP cookies. Cookies can be used
//// with both requests and responses.

import gleam/list
import gleam/option
import gleam/string

/// SameSite cookie attribute
pub type SameSite {
  Strict
  Lax
  None
}

/// HTTP cookie type
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
pub fn cookie_name(cookie: Cookie) -> String {
  let Cookie(name, _, _, _, _, _, _, _, _) = cookie
  name
}

/// Get the value of a cookie
pub fn cookie_value(cookie: Cookie) -> String {
  let Cookie(_, value, _, _, _, _, _, _, _) = cookie
  value
}

/// Create a simple cookie with just name and value
///
/// Creates an unsecured cookie with no expiration. Use `secure_cookie()` for
/// sensitive data like sessions or authentication tokens.
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
/// Sets `secure=True`, `httpOnly=True`, and `sameSite=Strict`. Use this for
/// session IDs, authentication tokens, or any sensitive data. The httpOnly flag
/// prevents JavaScript access, protecting against XSS attacks.
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

/// Remove a cookie by name
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie) {
  let normalized_name = string.lowercase(name)
  filter_matching_cookies(cookies, normalized_name)
}
