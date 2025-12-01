//// Tests for dream/http/validation module.

import dream/http/validation
import dream_test/assertions/should.{
  contain_string, equal, not_equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/dynamic/decode
import matchers/extract_user_name.{extract_user_name}
import matchers/extract_validation_error_field.{extract_validation_error_field}
import matchers/extract_validation_error_message.{
  extract_validation_error_message,
}

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

pub fn tests() -> UnitTest {
  describe("validation", [
    describe("validate_json", [
      it("decodes valid JSON to user name", fn() {
        // Arrange
        let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_user_name(fn(user: TestUser) { user.name })
        |> equal("John")
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
        |> equal("john@example.com")
        |> or_fail_with("Email should be 'john@example.com'")
      }),
      it("returns error for invalid JSON syntax", fn() {
        // Arrange
        let body = "{invalid json"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_validation_error_message()
        |> not_equal("")
        |> or_fail_with("Should have error message")
      }),
      it("returns error with field name for wrong type", fn() {
        // Arrange
        let body = "{\"name\": 123, \"email\": \"john@example.com\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_validation_error_field()
        |> equal("name")
        |> or_fail_with("Field should be 'name'")
      }),
      it("returns error with field name for missing field", fn() {
        // Arrange
        let body = "{\"name\": \"John\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_validation_error_field()
        |> equal("email")
        |> or_fail_with("Field should be 'email'")
      }),
      it("returns descriptive error message for wrong type", fn() {
        // Arrange
        let body = "{\"name\": 123, \"email\": \"john@example.com\"}"

        // Act
        let result = validation.validate_json(body, user_decoder())

        // Assert
        result
        |> should()
        |> extract_validation_error_message()
        |> contain_string("name")
        |> or_fail_with("Error message should mention field name")
      }),
    ]),
  ])
}
