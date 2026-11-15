import dream_test/assertions/should.{be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/testing_guide_user.{create_user}

pub fn tests() -> UnitTest {
  describe("users", [
    it("creates user with valid data", fn() {
      create_user("Alice", "alice@example.com")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create user")
    }),
  ])
}
