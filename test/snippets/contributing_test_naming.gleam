//// Test naming: describe the function, name each test for its result and
//// condition. Shown in docs/contributing/contributing.md.

import dream/http/error.{BadRequest, InternalServerError, NotFound}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("dream/http/error", [to_status_code_tests(), message_tests()])
}

fn to_status_code_tests() -> UnitTest {
  describe("to_status_code", [
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
  ])
}

fn message_tests() -> UnitTest {
  describe("message", [
    it("returns the message of a BadRequest", fn() {
      error.message(BadRequest("Invalid email format"))
      |> should()
      |> equal("Invalid email format")
      |> or_fail_with("Expected the BadRequest message")
    }),
    it("returns the message of an InternalServerError", fn() {
      error.message(InternalServerError("Database connection failed"))
      |> should()
      |> equal("Database connection failed")
      |> or_fail_with("Expected the InternalServerError message")
    }),
  ])
}
