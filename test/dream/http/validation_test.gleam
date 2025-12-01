//// Tests for dream/http/validation module.

import dream/http/validation
import dream_test/assertions/should.{equal, not_equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/dynamic/decode

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
// Helper Functions
// ============================================================================

fn get_user_name(result: Result(TestUser, validation.ValidationError)) -> String {
  case result {
    Ok(user) -> user.name
    Error(_) -> ""
  }
}

fn get_user_email(
  result: Result(TestUser, validation.ValidationError),
) -> String {
  case result {
    Ok(user) -> user.email
    Error(_) -> ""
  }
}

fn get_error_message(result: Result(a, validation.ValidationError)) -> String {
  case result {
    Ok(_) -> ""
    Error(validation.ValidationError(message, _, _, _)) -> message
  }
}

fn get_error_field(result: Result(a, validation.ValidationError)) -> String {
  case result {
    Ok(_) -> ""
    Error(validation.ValidationError(_, field, _, _)) ->
      case field {
        option.Some(field_name) -> field_name
        option.None -> ""
      }
  }
}

import gleam/option

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("validation", [
    describe("validate_json", [
      it("decodes valid JSON to user name", fn() {
        let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

        validation.validate_json(body, user_decoder())
        |> get_user_name()
        |> should()
        |> equal("John")
        |> or_fail_with("Name should be 'John'")
      }),
      it("decodes valid JSON to user email", fn() {
        let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

        validation.validate_json(body, user_decoder())
        |> get_user_email()
        |> should()
        |> equal("john@example.com")
        |> or_fail_with("Email should be 'john@example.com'")
      }),
      it("returns error for invalid JSON syntax", fn() {
        let body = "{invalid json"

        validation.validate_json(body, user_decoder())
        |> get_error_message()
        |> should()
        |> not_equal("")
        |> or_fail_with("Should have error message")
      }),
      it("returns error with field name for wrong type", fn() {
        let body = "{\"name\": 123, \"email\": \"john@example.com\"}"

        validation.validate_json(body, user_decoder())
        |> get_error_field()
        |> should()
        |> equal("name")
        |> or_fail_with("Field should be 'name'")
      }),
      it("returns error with field name for missing field", fn() {
        let body = "{\"name\": \"John\"}"

        validation.validate_json(body, user_decoder())
        |> get_error_field()
        |> should()
        |> equal("email")
        |> or_fail_with("Field should be 'email'")
      }),
    ]),
  ])
}
