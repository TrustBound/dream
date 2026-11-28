//// Example for the doc of `cookie.cookie_name`.

import dream/http/cookie

pub fn session_cookie_name() -> String {
  let session_cookie = cookie.simple_cookie("session_id", "abc123")
  // Returns "session_id"
  cookie.cookie_name(session_cookie)
}
