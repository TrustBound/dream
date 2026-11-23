//// Example for the doc of `transaction.simple_cookie`.

import dream/http/transaction.{type Cookie, simple_cookie}

pub fn theme_cookie() -> Cookie {
  // Not secure, not httpOnly, no SameSite, no expiry
  simple_cookie("theme", "dark")
}
