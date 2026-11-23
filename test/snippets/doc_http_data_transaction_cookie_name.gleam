//// Example for the doc of `transaction.cookie_name`.

import dream/http/transaction.{cookie_name, simple_cookie}

pub fn theme_cookie_name() -> String {
  let cookie = simple_cookie("theme", "dark")
  // "theme"
  cookie_name(cookie)
}
