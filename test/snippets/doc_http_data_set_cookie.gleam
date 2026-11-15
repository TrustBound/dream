//// Example for the doc of `cookie.set_cookie`.

import dream/http/cookie.{type Cookie}

pub fn updated_cookies() -> List(Cookie) {
  let cookies = [cookie.simple_cookie("theme", "light")]

  // Replace existing cookie
  let updated =
    cookie.set_cookie(cookies, cookie.simple_cookie("theme", "dark"))
  // Result: [Cookie("theme", "dark", ...)]

  // Add new cookie
  let with_session =
    cookie.set_cookie(updated, cookie.secure_cookie("session_id", "abc123"))
  // Result: [
  //   Cookie("session_id", "abc123", ...),
  //   Cookie("theme", "dark", ...)
  // ]
  with_session
}
