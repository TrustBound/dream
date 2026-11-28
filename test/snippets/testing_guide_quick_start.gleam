import dream_test/matchers.{be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/testing_guide_user.{create_user}

pub fn tests() -> TestSuite {
  describe("users", [
    it("creates user with valid data", fn() {
      create_user("Alice", "alice@example.com")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create user")
    }),
  ])
}
