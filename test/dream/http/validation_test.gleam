import dream/http/validation
import gleam/dynamic/decode
import gleam/option
import gleeunit/should

type TestUser {
  TestUser(name: String, email: String)
}

fn user_decoder() -> decode.Decoder(TestUser) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(TestUser(name: name, email: email))
}

pub fn validate_json_with_valid_data_returns_decoded_data_test() {
  // Arrange
  let body = "{\"name\": \"John\", \"email\": \"john@example.com\"}"

  // Act
  let result = validation.validate_json(body, user_decoder())

  // Assert
  case result {
    Ok(user) -> {
      user.name |> should.equal("John")
      user.email |> should.equal("john@example.com")
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_json_with_invalid_json_returns_error_test() {
  // Arrange
  let body = "{invalid json"

  // Act
  let result = validation.validate_json(body, user_decoder())

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(validation.ValidationError(message, _, _, _)) -> {
      message |> should.not_equal("")
    }
  }
}

pub fn validate_json_with_wrong_types_returns_error_with_details_test() {
  // Arrange
  let body = "{\"name\": 123, \"email\": \"john@example.com\"}"

  // Act
  let result = validation.validate_json(body, user_decoder())

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(validation.ValidationError(message, field, _expected, _found)) -> {
      message |> should.not_equal("")
      // Validation error should have field details
      case field {
        option.Some(f) -> f |> should.equal("name")
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_json_with_missing_fields_returns_error_test() {
  // Arrange
  let body = "{\"name\": \"John\"}"

  // Act
  let result = validation.validate_json(body, user_decoder())

  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(validation.ValidationError(_, field, _, _)) -> {
      case field {
        option.Some(f) -> f |> should.equal("email")
        option.None -> should.fail()
      }
    }
  }
}
