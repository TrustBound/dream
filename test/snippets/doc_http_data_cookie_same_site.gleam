//// Example for the doc of `cookie.SameSite`.

import dream/http/cookie.{type Cookie, Cookie, Lax}
import gleam/option

pub fn session_cookie() -> Cookie {
  Cookie(
    ..cookie.secure_cookie("session", "abc123"),
    same_site: option.Some(Lax),
  )
}
