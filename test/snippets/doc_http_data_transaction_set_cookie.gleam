//// Example for the doc of `transaction.set_cookie`.

import dream/http/transaction.{type Cookie, set_cookie, simple_cookie}

pub fn dark_theme() -> List(Cookie) {
  let cookies = [simple_cookie("theme", "light")]
  // The new cookie replaces the old one: [simple_cookie("theme", "dark")]
  set_cookie(cookies, simple_cookie("theme", "dark"))
}
