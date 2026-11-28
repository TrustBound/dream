//// Example for the doc of `cookie.cookie_value`.

import dream/http/cookie

pub fn session_cookie_value() -> String {
  let session_cookie = cookie.simple_cookie("session_id", "abc123")
  // Returns "abc123"
  cookie.cookie_value(session_cookie)
}
