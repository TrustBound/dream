//// Tests for dream/http/cookie module.

import dream/http/cookie.{
  cookie_name, cookie_value, get_cookie_value, secure_cookie, simple_cookie,
}
import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}

pub fn tests() -> TestSuite {
  describe("cookie", [
    group("simple_cookie", [
      it("creates cookie with correct name", fn() {
        // Arrange
        let name = "theme"
        let value = "dark"

        // Act
        let cookie = simple_cookie(name, value)

        // Assert
        cookie
        |> cookie_name()
        |> should()
        |> be_equal(name)
        |> or_fail_with("Cookie name should be 'theme'")
      }),
      it("creates cookie with correct value", fn() {
        // Arrange
        let name = "theme"
        let value = "dark"

        // Act
        let cookie = simple_cookie(name, value)

        // Assert
        cookie
        |> cookie_value()
        |> should()
        |> be_equal(value)
        |> or_fail_with("Cookie value should be 'dark'")
      }),
    ]),
    group("secure_cookie", [
      it("creates cookie that can be retrieved by name", fn() {
        // Arrange
        let cookie = secure_cookie("session", "token123")

        // Act
        let result = get_cookie_value([cookie], "session")

        // Assert
        result
        |> should()
        |> be_some()
        |> be_equal("token123")
        |> or_fail_with("Secure cookie should have value 'token123'")
      }),
    ]),
  ])
}
