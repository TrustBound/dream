//// Tests for dream/http/error module.

import dream/http/error.{
  BadRequest, Forbidden, InternalServerError, NotFound, Unauthorized,
  UnprocessableContent, message, to_status_code,
}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("error", [
    to_status_code_tests(),
    message_tests(),
  ])
}

fn to_status_code_tests() -> UnitTest {
  describe("to_status_code", [
    it("BadRequest returns 400", fn() {
      to_status_code(BadRequest("Invalid parameter"))
      |> should()
      |> equal(400)
      |> or_fail_with("BadRequest should return 400")
    }),
    it("Unauthorized returns 401", fn() {
      to_status_code(Unauthorized("Authentication required"))
      |> should()
      |> equal(401)
      |> or_fail_with("Unauthorized should return 401")
    }),
    it("Forbidden returns 403", fn() {
      to_status_code(Forbidden("Access denied"))
      |> should()
      |> equal(403)
      |> or_fail_with("Forbidden should return 403")
    }),
    it("NotFound returns 404", fn() {
      to_status_code(NotFound("Resource not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("NotFound should return 404")
    }),
    it("UnprocessableContent returns 422", fn() {
      to_status_code(UnprocessableContent("Validation failed"))
      |> should()
      |> equal(422)
      |> or_fail_with("UnprocessableContent should return 422")
    }),
    it("InternalServerError returns 500", fn() {
      to_status_code(InternalServerError("Database error"))
      |> should()
      |> equal(500)
      |> or_fail_with("InternalServerError should return 500")
    }),
  ])
}

fn message_tests() -> UnitTest {
  describe("message", [
    it("extracts BadRequest message", fn() {
      message(BadRequest("Invalid parameter"))
      |> should()
      |> equal("Invalid parameter")
      |> or_fail_with("Should extract BadRequest message")
    }),
    it("extracts Unauthorized message", fn() {
      message(Unauthorized("Authentication required"))
      |> should()
      |> equal("Authentication required")
      |> or_fail_with("Should extract Unauthorized message")
    }),
    it("extracts Forbidden message", fn() {
      message(Forbidden("Access denied"))
      |> should()
      |> equal("Access denied")
      |> or_fail_with("Should extract Forbidden message")
    }),
    it("extracts NotFound message", fn() {
      message(NotFound("Resource not found"))
      |> should()
      |> equal("Resource not found")
      |> or_fail_with("Should extract NotFound message")
    }),
    it("extracts UnprocessableContent message", fn() {
      message(UnprocessableContent("Validation failed"))
      |> should()
      |> equal("Validation failed")
      |> or_fail_with("Should extract UnprocessableContent message")
    }),
    it("extracts InternalServerError message", fn() {
      message(InternalServerError("Database error"))
      |> should()
      |> equal("Database error")
      |> or_fail_with("Should extract InternalServerError message")
    }),
    it("handles empty string message", fn() {
      message(BadRequest(""))
      |> should()
      |> equal("")
      |> or_fail_with("Should handle empty message")
    }),
    it("handles long message", fn() {
      let long_message =
        "This is a very long error message that contains multiple words and should be preserved exactly as provided"

      message(NotFound(long_message))
      |> should()
      |> equal(long_message)
      |> or_fail_with("Should preserve long message")
    }),
    it("handles special characters", fn() {
      let special_message = "Error: Invalid input 'user@example.com' & password"

      message(BadRequest(special_message))
      |> should()
      |> equal(special_message)
      |> or_fail_with("Should preserve special characters")
    }),
  ])
}
