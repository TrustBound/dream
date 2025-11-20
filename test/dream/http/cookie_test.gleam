import dream/http/cookie.{
  cookie_name, cookie_value, get_cookie_value, secure_cookie, simple_cookie,
}
import gleam/option
import gleeunit/should

pub fn simple_cookie_with_name_and_value_creates_cookie_with_defaults_test() {
  let cookie = simple_cookie("theme", "dark")
  cookie_name(cookie) |> should.equal("theme")
  cookie_value(cookie) |> should.equal("dark")
}

pub fn secure_cookie_with_name_and_value_creates_secure_cookie_test() {
  let secure_cookie_value = secure_cookie("session", "token123")

  case get_cookie_value([secure_cookie_value], "session") {
    option.Some(value) -> value |> should.equal("token123")
    option.None -> should.fail()
  }
}
