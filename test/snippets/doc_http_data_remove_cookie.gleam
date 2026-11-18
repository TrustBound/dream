//// Example for the doc of `cookie.remove_cookie`.

import dream/http/cookie.{type Cookie, Cookie}
import gleam/option

pub fn without_theme() -> List(Cookie) {
  let cookies = [
    cookie.simple_cookie("theme", "dark"),
    cookie.secure_cookie("session_id", "abc123"),
  ]

  // Remove theme cookie from list
  cookie.remove_cookie(cookies, "theme")
  // Result: [Cookie("session_id", "abc123", ...)]
}

pub fn expired_session() -> Cookie {
  // To delete in browser, set expired cookie:
  Cookie(
    ..cookie.secure_cookie("session_id", ""),
    // Expire immediately
    max_age: option.Some(0),
  )
}
