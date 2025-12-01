//// Tests for dream/http/cookie module.

import dream/http/cookie.{
  cookie_name, cookie_value, get_cookie_value, secure_cookie, simple_cookie,
}
import dream_test/assertions/should.{be_some, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("cookie", [
    describe("simple_cookie", [
      it("creates cookie with correct name", fn() {
        simple_cookie("theme", "dark")
        |> cookie_name()
        |> should()
        |> equal("theme")
        |> or_fail_with("Cookie name should be 'theme'")
      }),
      it("creates cookie with correct value", fn() {
        simple_cookie("theme", "dark")
        |> cookie_value()
        |> should()
        |> equal("dark")
        |> or_fail_with("Cookie value should be 'dark'")
      }),
    ]),
    describe("secure_cookie", [
      it("creates cookie that can be retrieved by name", fn() {
        let cookie = secure_cookie("session", "token123")

        get_cookie_value([cookie], "session")
        |> should()
        |> be_some()
        |> equal("token123")
        |> or_fail_with("Secure cookie should have value 'token123'")
      }),
    ]),
  ])
}
