import dream_test/assertions/should.{be_error, be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/testing_guide_user as user

pub fn tests() -> UnitTest {
  describe("user", [
    describe("validate_email", [
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
