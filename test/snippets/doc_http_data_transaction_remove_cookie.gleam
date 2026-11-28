//// Example for the doc of `transaction.remove_cookie`.

import dream/http/transaction.{type Cookie, remove_cookie, simple_cookie}

pub fn without_theme() -> List(Cookie) {
  let cookies = [simple_cookie("theme", "dark"), simple_cookie("lang", "en")]
  // [simple_cookie("lang", "en")]
  remove_cookie(cookies, "theme")
}
