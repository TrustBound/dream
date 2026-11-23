import dream/http/error.{BadRequest, NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{after_each, before_each, describe, it}

pub fn tests() -> TestSuite {
  describe("tests with setup", [
    before_each(fn() {
      // Runs before each test
      Ok(Nil)
    }),
    after_each(fn() {
      // Runs after each test
      Ok(Nil)
    }),
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> be_equal(404)
      |> or_fail_with("Expected 404")
    }),
    it("returns 400 for BadRequest", fn() {
      error.to_status_code(BadRequest("Invalid email format"))
      |> should()
      |> be_equal(400)
      |> or_fail_with("Expected 400")
    }),
  ])
}
