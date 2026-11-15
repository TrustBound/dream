//// Example for the doc of `cookie.get_cookie_value`.

import dream/http/cookie
import gleam/option.{type Option}

pub fn lookups() -> #(Option(String), Option(String)) {
  let cookies = [
    cookie.simple_cookie("theme", "dark"),
    cookie.secure_cookie("session_id", "abc123"),
  ]

  // Some("dark")
  let theme = cookie.get_cookie_value(cookies, "theme")
  // None
  let missing = cookie.get_cookie_value(cookies, "missing")
  #(theme, missing)
}
