//// Example for the doc of `cookie.Cookie`.

import dream/http/cookie.{type Cookie, Cookie, Strict}
import gleam/option

pub fn builder_cookie() -> Cookie {
  // Using builder (recommended)
  cookie.secure_cookie("auth_token", "xyz789")
}

pub fn manual_cookie() -> Cookie {
  // Constructing manually
  Cookie(
    name: "auth_token",
    value: "xyz789",
    expires: option.None,
    // 1 hour
    max_age: option.Some(3600),
    domain: option.None,
    path: option.Some("/"),
    secure: True,
    http_only: True,
    same_site: option.Some(Strict),
  )
}
