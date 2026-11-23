//// Test naming: describe the function, name each test for its result and
//// condition. Shown in docs/contributing/contributing.md.

import dream/http/error.{BadRequest, InternalServerError, NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}

pub fn tests() -> TestSuite {
  describe("dream/http/error", [to_status_code_tests(), message_tests()])
}

fn to_status_code_tests() -> UnitNode {
  group("to_status_code", [
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> be_equal(404)
      |> or_fail_with("Expected 404")
    }),
  ])
}

fn message_tests() -> UnitNode {
  group("message", [
    it("returns the message of a BadRequest", fn() {
      error.message(BadRequest("Invalid email format"))
      |> should()
      |> be_equal("Invalid email format")
      |> or_fail_with("Expected the BadRequest message")
    }),
    it("returns the message of an InternalServerError", fn() {
      error.message(InternalServerError("Database connection failed"))
      |> should()
      |> be_equal("Database connection failed")
      |> or_fail_with("Expected the InternalServerError message")
    }),
  ])
}
