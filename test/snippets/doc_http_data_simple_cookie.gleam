//// Example for the doc of `cookie.simple_cookie`.

import dream/http/cookie.{type Cookie}

pub fn preference_cookies() -> List(Cookie) {
  [
    // User preference cookie
    cookie.simple_cookie("theme", "dark"),
    // Language preference
    cookie.simple_cookie("lang", "en"),
  ]
}
