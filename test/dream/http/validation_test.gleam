//// Tests for dream/http/validation module.

import dream/http/validation.{type ValidationError, ValidationError}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/dynamic/decode
import gleam/option.{None, Some}
import matchers/extract_user_name.{extract_user_name}

// ============================================================================
// Test Types
// ============================================================================

type TestUser {
  TestUser(name: String, email: String)
}

fn user_decoder() -> decode.Decoder(TestUser) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(TestUser(name: name, email: email))
}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("validation", [
    group("validate_json", [
      it("decodes valid JSON to user name", fn() {
        // Arrange
        let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_user_name(fn(user: TestUser) { user.name })
        |> be_equal("John")
        |> or_fail_with("Name should be 'John'")
      }),
      it("decodes valid JSON to user email", fn() {
        // Arrange
        let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_user_name(fn(user: TestUser) { user.email })
        |> be_equal("john@example.com")
        |> or_fail_with("Email should be 'john@example.com'")
      }),
      it("returns the syntax error for invalid JSON syntax", fn() {
        // Arrange
        let body = "{invalid json"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> be_equal(Error([syntax_error("Unexpected byte: 0x69")]))
        |> or_fail_with("A syntax error should be the one error")
      }),
      it("returns one error for each of two wrong fields", fn() {
        // Arrange
        let body = "{\"name\": 123, \"email\": true}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> be_equal(
          Error([
            ValidationError(
              message: "Expected String but found Int at name",
              field: Some("name"),
              expected: Some("String"),
              found: Some("Int"),
            ),
            ValidationError(
              message: "Expected String but found Bool at email",
              field: Some("email"),
              expected: Some("String"),
              found: Some("Bool"),
            ),
          ]),
        )
        |> or_fail_with("Each wrong field should give its own error")
      }),
      it("returns the error of a missing field", fn() {
        // Arrange
        let body = "{\"name\": \"John\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> be_equal(
          Error([
            ValidationError(
              message: "Expected Field but found Nothing at email",
              field: Some("email"),
              expected: Some("Field"),
              found: Some("Nothing"),
            ),
          ]),
        )
        |> or_fail_with("A missing field should give one error")
      }),
    ]),
    json_error_tests(),
  ])
}

fn json_error_tests() -> UnitNode {
  group("JSON syntax errors", [
    it("names an invalid escape sequence", fn() {
      // Arrange
      let body = "\"\\u12zz\""

      // Act
      let result = validation.validate_json(body, user_decoder())

      // Assert
      result
      |> should()
      |> be_equal(Error([syntax_error("Unexpected sequence: \\u12zz")]))
      |> or_fail_with("The message should name the bad escape")
    }),
  ])
}

fn syntax_error(message: String) -> ValidationError {
  ValidationError(message: message, field: None, expected: None, found: None)
}
