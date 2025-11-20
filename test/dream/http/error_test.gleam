//// Tests for Dream unified error type
////
//// Black box tests following arrange-act-assert pattern.
//// Tests verify behavior, not implementation details.

import dream/http/error.{
  BadRequest, Forbidden, InternalServerError, NotFound, Unauthorized,
  UnprocessableContent, message, to_status_code,
}
import gleeunit/should

// Status code conversion tests

pub fn to_status_code_bad_request_returns_400_test() {
  // Arrange
  let error = BadRequest("Invalid parameter")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(400)
}

pub fn to_status_code_unauthorized_returns_401_test() {
  // Arrange
  let error = Unauthorized("Authentication required")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(401)
}

pub fn to_status_code_forbidden_returns_403_test() {
  // Arrange
  let error = Forbidden("Access denied")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(403)
}

pub fn to_status_code_not_found_returns_404_test() {
  // Arrange
  let error = NotFound("Resource not found")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(404)
}

pub fn to_status_code_unprocessable_content_returns_422_test() {
  // Arrange
  let error = UnprocessableContent("Validation failed")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(422)
}

pub fn to_status_code_internal_server_error_returns_500_test() {
  // Arrange
  let error = InternalServerError("Database error")

  // Act
  let status = to_status_code(error)

  // Assert
  status |> should.equal(500)
}

// Error message extraction tests

pub fn message_bad_request_returns_message_test() {
  // Arrange
  let msg = "Invalid parameter"
  let error = BadRequest(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_unauthorized_returns_message_test() {
  // Arrange
  let msg = "Authentication required"
  let error = Unauthorized(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_forbidden_returns_message_test() {
  // Arrange
  let msg = "Access denied"
  let error = Forbidden(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_not_found_returns_message_test() {
  // Arrange
  let msg = "Resource not found"
  let error = NotFound(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_unprocessable_content_returns_message_test() {
  // Arrange
  let msg = "Validation failed"
  let error = UnprocessableContent(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_internal_server_error_returns_message_test() {
  // Arrange
  let msg = "Database error"
  let error = InternalServerError(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_handles_empty_string_test() {
  // Arrange
  let error = BadRequest("")

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal("")
}

pub fn message_handles_long_message_test() {
  // Arrange
  let msg =
    "This is a very long error message that contains multiple words and should be preserved exactly as provided"
  let error = NotFound(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}

pub fn message_handles_special_characters_test() {
  // Arrange
  let msg = "Error: Invalid input 'user@example.com' & password"
  let error = BadRequest(msg)

  // Act
  let extracted = message(error)

  // Assert
  extracted |> should.equal(msg)
}
