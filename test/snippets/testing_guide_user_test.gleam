import dream_test/matchers.{be_error, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import snippets/testing_guide_user as user

pub fn tests() -> TestSuite {
  describe("user", [
    group("validate_email", [
      it("accepts valid email", fn() {
        user.validate_email("alice@example.com")
        |> should()
        |> be_ok()
        |> or_fail_with("Should accept valid email")
      }),
      it("rejects empty email", fn() {
        user.validate_email("")
        |> should()
        |> be_error()
        |> or_fail_with("Should reject empty email")
      }),
    ]),
  ])
}
