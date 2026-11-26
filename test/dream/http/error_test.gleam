//// Tests for dream/http/error module.

import dream/http/error.{
  BadRequest, Conflict, Forbidden, GatewayTimeout, InternalServerError, NotFound,
  ServiceUnavailable, Unauthorized, UnprocessableContent, from_shared, message,
  to_status_code,
}
import dream_errors
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/list

pub fn tests() -> TestSuite {
  describe("error", [
    to_status_code_tests(),
    message_tests(),
    new_variant_tests(),
    from_shared_tests(),
  ])
}

fn to_status_code_tests() -> UnitNode {
  group("to_status_code", [
    it("BadRequest returns 400", fn() {
      // Arrange
      let error = BadRequest("Invalid parameter")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> be_equal(400)
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
      |> be_equal(401)
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
      |> be_equal(403)
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
      |> be_equal(404)
      |> or_fail_with("NotFound should return 404")
    }),
    it("Conflict returns 409", fn() {
      // Arrange
      let error = Conflict("Email already registered")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> be_equal(409)
      |> or_fail_with("Conflict should return 409")
    }),
    it("UnprocessableContent returns 422", fn() {
      // Arrange
      let error = UnprocessableContent("Validation failed")

      // Act
      let result = to_status_code(error)

      // Assert
      result
      |> should()
      |> be_equal(422)
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
      |> be_equal(500)
      |> or_fail_with("InternalServerError should return 500")
    }),
  ])
}

fn message_tests() -> UnitNode {
  group("message", [
    it("extracts BadRequest message", fn() {
      // Arrange
      let error = BadRequest("Invalid parameter")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> be_equal("Invalid parameter")
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
      |> be_equal("Authentication required")
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
      |> be_equal("Access denied")
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
      |> be_equal("Resource not found")
      |> or_fail_with("Should extract NotFound message")
    }),
    it("extracts Conflict message", fn() {
      // Arrange
      let error = Conflict("Email already registered")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> be_equal("Email already registered")
      |> or_fail_with("Should extract Conflict message")
    }),
    it("extracts UnprocessableContent message", fn() {
      // Arrange
      let error = UnprocessableContent("Validation failed")

      // Act
      let result = message(error)

      // Assert
      result
      |> should()
      |> be_equal("Validation failed")
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
      |> be_equal("Database error")
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
      |> be_equal("")
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
      |> be_equal(long_message)
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
      |> be_equal(special_message)
      |> or_fail_with("Should preserve special characters")
    }),
  ])
}

fn new_variant_tests() -> UnitNode {
  group("ServiceUnavailable and GatewayTimeout", [
    it("ServiceUnavailable returns 503 and its message", fn() {
      // Arrange
      let error = ServiceUnavailable("Database pool is full")

      // Act
      let result = #(to_status_code(error), message(error))

      // Assert
      result
      |> should()
      |> be_equal(#(503, "Database pool is full"))
      |> or_fail_with("ServiceUnavailable should return 503 and its message")
    }),
    it("GatewayTimeout returns 504 and its message", fn() {
      // Arrange
      let error = GatewayTimeout("Payment API did not answer")

      // Act
      let result = #(to_status_code(error), message(error))

      // Assert
      result
      |> should()
      |> be_equal(#(504, "Payment API did not answer"))
      |> or_fail_with("GatewayTimeout should return 504 and its message")
    }),
  ])
}

fn from_shared_tests() -> UnitNode {
  group("from_shared", [
    it("gives each kind its error with a generic text", fn() {
      // Arrange
      let shared = [
        dream_errors.NotFound("users.get found no row"),
        dream_errors.Conflict("users_email_key violated", "cause"),
        dream_errors.Invalid("age -1 is out of range", "cause"),
        dream_errors.Unavailable("no connection to db.internal", "cause"),
        dream_errors.Timeout("query on users took 5000 ms", "cause"),
        dream_errors.Failed("relation users does not exist", "cause"),
      ]

      // Act
      let result = shared |> list.map(from_shared)

      // Assert
      result
      |> should()
      |> be_equal([
        NotFound("Not found"),
        Conflict("Conflict"),
        UnprocessableContent("Invalid input"),
        ServiceUnavailable("Service unavailable"),
        GatewayTimeout("Timed out"),
        InternalServerError("Internal server error"),
      ])
      |> or_fail_with("from_shared should map each kind with a generic text")
    }),
    it("gives the status of each kind", fn() {
      // Arrange
      let shared = [
        dream_errors.NotFound("a"),
        dream_errors.Conflict("b", Nil),
        dream_errors.Invalid("c", Nil),
        dream_errors.Unavailable("d", Nil),
        dream_errors.Timeout("e", Nil),
        dream_errors.Failed("f", Nil),
      ]

      // Act
      let result =
        shared |> list.map(fn(error) { to_status_code(from_shared(error)) })

      // Assert
      result
      |> should()
      |> be_equal([404, 409, 422, 503, 504, 500])
      |> or_fail_with("from_shared should give 404, 409, 422, 503, 504, 500")
    }),
  ])
}
