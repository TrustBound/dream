//// Example for the doc of `cookie.secure_cookie`.

import dream/http/cookie.{type Cookie}

pub fn login_cookies(
  session_id: String,
  jwt_token: String,
  csrf_token: String,
) -> List(Cookie) {
  [
    // Session cookie
    cookie.secure_cookie("session_id", session_id),
    // Authentication token
    cookie.secure_cookie("auth_token", jwt_token),
    // CSRF token
    cookie.secure_cookie("csrf_token", csrf_token),
  ]
}
