import dream/http/error.{BadRequest, NotFound}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}

pub fn tests() -> UnitTest {
  describe("tests with setup", [
    before_each(fn() {
      // Runs before each test
      AssertionOk
    }),
    after_each(fn() {
      // Runs after each test
      AssertionOk
    }),
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
    it("returns 400 for BadRequest", fn() {
      error.to_status_code(BadRequest("Invalid email format"))
      |> should()
      |> equal(400)
      |> or_fail_with("Expected 400")
    }),
  ])
}
