//// Example for the doc of `transaction.cookie_value`.

import dream/http/transaction.{cookie_value, simple_cookie}

pub fn theme_cookie_value() -> String {
  let cookie = simple_cookie("theme", "dark")
  // "dark"
  cookie_value(cookie)
}
