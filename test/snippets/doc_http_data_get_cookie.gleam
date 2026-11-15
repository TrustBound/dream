//// Example for the doc of `cookie.get_cookie`.

import dream/http/cookie.{type Cookie}
import gleam/option.{type Option, None, Some}

pub fn example_cookies() -> List(Cookie) {
  [
    cookie.simple_cookie("theme", "dark"),
    cookie.secure_cookie("session_id", "abc123"),
  ]
}

pub fn session_value(cookies: List(Cookie)) -> String {
  case cookie.get_cookie(cookies, "session_id") {
    // "abc123"
    Some(session_cookie) -> cookie.cookie_value(session_cookie)
    None -> "no session"
  }
}

pub fn theme_cookie(cookies: List(Cookie)) -> Option(Cookie) {
  // Case-insensitive: Some(Cookie("theme", "dark", ...))
  cookie.get_cookie(cookies, "THEME")
}
