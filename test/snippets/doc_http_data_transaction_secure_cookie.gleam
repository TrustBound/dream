//// Example for the doc of `transaction.secure_cookie`.

import dream/http/transaction.{type Cookie, secure_cookie}

pub fn session_cookie() -> Cookie {
  // secure: True, http_only: True, same_site: Some(Strict)
  secure_cookie("session_id", "abc123")
}
