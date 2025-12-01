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
      // Arrange
      let error = BadRequest("Invalid parameter")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(400)
      |> or_fail_with("BadRequest should return 400")
    }),
    it("Unauthorized returns 401", fn() {
      // Arrange
      let error = Unauthorized("Authentication required")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(401)
      |> or_fail_with("Unauthorized should return 401")
    }),
    it("Forbidden returns 403", fn() {
      // Arrange
      let error = Forbidden("Access denied")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(403)
      |> or_fail_with("Forbidden should return 403")
    }),
    it("NotFound returns 404", fn() {
      // Arrange
      let error = NotFound("Resource not found")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(404)
      |> or_fail_with("NotFound should return 404")
    }),
    it("UnprocessableContent returns 422", fn() {
      // Arrange
      let error = UnprocessableContent("Validation failed")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(422)
      |> or_fail_with("UnprocessableContent should return 422")
    }),
    it("InternalServerError returns 500", fn() {
      // Arrange
      let error = InternalServerError("Database error")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> equal(500)
      |> or_fail_with("InternalServerError should return 500")
    }),
  ])
}

fn message_tests() -> UnitTest {
  describe("message", [
    it("extracts BadRequest message", fn() {
      // Arrange
      let error = BadRequest("Invalid parameter")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Invalid parameter")
      |> or_fail_with("Should extract BadRequest message")
    }),
    it("extracts Unauthorized message", fn() {
      // Arrange
      let error = Unauthorized("Authentication required")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Authentication required")
      |> or_fail_with("Should extract Unauthorized message")
    }),
    it("extracts Forbidden message", fn() {
      // Arrange
      let error = Forbidden("Access denied")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Access denied")
      |> or_fail_with("Should extract Forbidden message")
    }),
    it("extracts NotFound message", fn() {
      // Arrange
      let error = NotFound("Resource not found")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Resource not found")
      |> or_fail_with("Should extract NotFound message")
    }),
    it("extracts UnprocessableContent message", fn() {
      // Arrange
      let error = UnprocessableContent("Validation failed")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Validation failed")
      |> or_fail_with("Should extract UnprocessableContent message")
    }),
    it("extracts InternalServerError message", fn() {
      // Arrange
      let error = InternalServerError("Database error")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("Database error")
      |> or_fail_with("Should extract InternalServerError message")
    }),
    it("handles empty string message", fn() {
      // Arrange
      let error = BadRequest("")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal("")
      |> or_fail_with("Should handle empty message")
    }),
    it("handles long message", fn() {
      // Arrange
      let long_message =
        "This is a very long error message that contains multiple words and should be preserved exactly as provided"
      let error = NotFound(long_message)

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal(long_message)
      |> or_fail_with("Should preserve long message")
    }),
    it("handles special characters", fn() {
      // Arrange
      let special_message = "Error: Invalid input 'user@example.com' & password"
      let error = BadRequest(special_message)

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> equal(special_message)
      |> or_fail_with("Should preserve special characters")
    }),
  ])
}
