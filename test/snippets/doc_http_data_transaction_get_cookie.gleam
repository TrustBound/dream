//// Example for the doc of `transaction.get_cookie`.

import dream/http/transaction.{
  type Cookie, get_cookie, secure_cookie, simple_cookie,
}
import gleam/option.{type Option}

pub fn session() -> Option(Cookie) {
  let cookies = [
    simple_cookie("theme", "dark"),
    secure_cookie("session_id", "abc123"),
  ]
  // The name match ignores case: Some(secure_cookie("session_id", "abc123"))
  get_cookie(cookies, "SESSION_ID")
}
