//// Example for the module doc of `dream/http/cookie`.

import dream/http/cookie.{type Cookie}
import dream/http/request.{type Request}
import gleam/option.{None, Some}

pub fn new_cookies() -> List(Cookie) {
  [
    // Simple cookie
    cookie.simple_cookie("theme", "dark"),
    // Secure cookie (recommended for sensitive data)
    cookie.secure_cookie("session_id", "abc123"),
  ]
}

pub fn session_status(request: Request) -> String {
  // Get cookie from request
  case cookie.get_cookie_value(request.cookies, "session_id") {
    Some(id) -> "Session " <> id
    None -> "No session cookie"
  }
}
