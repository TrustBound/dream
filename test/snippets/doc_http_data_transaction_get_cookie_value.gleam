//// Example for the doc of `transaction.get_cookie_value`.

import dream/http/transaction.{get_cookie_value, simple_cookie}
import gleam/option.{type Option}

pub fn theme() -> Option(String) {
  let cookies = [simple_cookie("theme", "dark")]
  // Some("dark")
  get_cookie_value(cookies, "theme")
}
