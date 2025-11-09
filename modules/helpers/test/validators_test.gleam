import dream_helpers/statuses
import dream/core/http/transaction
import dream_helpers/validators.{
  ValidationError, error_response, validate, validate_or_respond,
}
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should

type CustomType {
  CustomType(value: String)
}

pub fn validate_with_simple_string_decoder_returns_decoded_string_test() {
  let decoder = decode.string
  let json_body = "\"hello world\""

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> value |> should.equal("hello world")
    Error(_) -> should.fail()
  }
}

pub fn validate_with_tuple_decoder_returns_decoded_tuple_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(#(name, age))
  }
  let json_body = "{\"name\":\"Alice\",\"age\":30}"

  let result = validate(json_body, decoder)

  case result {
    Ok(#(name, age)) -> {
      name |> should.equal("Alice")
      age |> should.equal(30)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_integer_decoder_returns_decoded_int_test() {
  let decoder = decode.int
  let json_body = "42"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> value |> should.equal(42)
    Error(_) -> should.fail()
  }
}

pub fn validate_with_float_decoder_returns_decoded_float_test() {
  let decoder = decode.float
  let json_body = "3.14"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> {
      value |> should.equal(3.14)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_bool_decoder_returns_decoded_bool_test() {
  let decoder = decode.bool

  case validate("true", decoder) {
    Ok(value) -> value |> should.equal(True)
    Error(_) -> should.fail()
  }

  case validate("false", decoder) {
    Ok(value) -> value |> should.equal(False)
    Error(_) -> should.fail()
  }
}

pub fn validate_with_option_decoder_with_some_returns_some_test() {
  let decoder = decode.optional(decode.string)
  let json_body = "\"value\""

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> {
      case value {
        option.Some(v) -> v |> should.equal("value")
        option.None -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_option_decoder_with_null_returns_none_test() {
  let decoder = decode.optional(decode.string)
  let json_body = "null"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> {
      case value {
        option.Some(_) -> should.fail()
        option.None -> Nil
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_nested_object_decoder_returns_decoded_object_test() {
  let decoder = {
    use user <- decode.field("user", {
      use name <- decode.field("name", decode.string)
      use email <- decode.field("email", decode.string)
      decode.success(#(name, email))
    })
    decode.success(user)
  }
  let json_body = "{\"user\":{\"name\":\"Bob\",\"email\":\"bob@example.com\"}}"

  let result = validate(json_body, decoder)

  case result {
    Ok(#(name, email)) -> {
      name |> should.equal("Bob")
      email |> should.equal("bob@example.com")
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_list_decoder_returns_decoded_list_test() {
  let decoder = decode.list(decode.string)
  let json_body = "[\"a\",\"b\",\"c\"]"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> {
      list.length(value) |> should.equal(3)
      case value {
        [a, b, c] -> {
          a |> should.equal("a")
          b |> should.equal("b")
          c |> should.equal("c")
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_empty_string_returns_json_parse_error_test() {
  let decoder = decode.string
  let json_body = ""

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "JSON input") |> should.equal(True)
      case error.field {
        option.Some(_) -> should.fail()
        option.None -> Nil
      }
    }
  }
}

pub fn validate_with_malformed_json_unclosed_bracket_returns_error_test() {
  let decoder = decode.string
  let json_body = "{\"key\":\"value\""

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "JSON") |> should.equal(True)
    }
  }
}

pub fn validate_with_malformed_json_invalid_syntax_returns_error_test() {
  let decoder = decode.string
  let json_body = "{key: value}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      error.message |> should.equal(error.message)
    }
  }
}

pub fn validate_with_missing_required_field_returns_structure_error_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(#(name, age))
  }
  let json_body = "{\"name\":\"Alice\"}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "age") |> should.equal(True)
      case error.field {
        option.Some(field) -> field |> should.equal("age")
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_wrong_type_string_instead_of_int_returns_type_error_test() {
  let decoder = {
    use age <- decode.field("age", decode.int)
    decode.success(age)
  }
  let json_body = "{\"age\":\"thirty\"}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "Int") |> should.equal(True)
      case error.field {
        option.Some(field) -> field |> should.equal("age")
        option.None -> should.fail()
      }
      case error.expected {
        option.Some(expected) ->
          string.contains(expected, "Int") |> should.equal(True)
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_wrong_type_at_nested_path_returns_nested_error_test() {
  let decoder = {
    use user <- decode.field("user", {
      use age <- decode.field("age", decode.int)
      decode.success(age)
    })
    decode.success(user)
  }
  let json_body = "{\"user\":{\"age\":\"not a number\"}}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      case error.field {
        option.Some(field) ->
          string.contains(field, "user") |> should.equal(True)
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_multiple_errors_returns_first_error_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(#(name, age))
  }
  let json_body = "{\"name\":123,\"age\":\"not a number\"}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "name") |> should.equal(True)
      case error.field {
        option.Some(field) -> field |> should.equal("name")
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_invalid_array_elements_returns_error_test() {
  let decoder = decode.list(decode.int)
  let json_body = "[1,2,\"not a number\",4]"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "Int") |> should.equal(True)
      case error.field {
        option.Some(_field) -> Nil
        option.None -> should.fail()
      }
    }
  }
}

pub fn error_response_with_all_fields_populated_creates_json_response_test() {
  let error =
    ValidationError(
      message: "Expected Int but found String at age",
      field: option.Some("age"),
      expected: option.Some("Int"),
      found: option.Some("String"),
    )

  let response = error_response(error)

  case response {
    transaction.Response(status, body, _, _, content_type) -> {
      status |> should.equal(statuses.to_code(statuses.bad_request_status()))
      case content_type {
        option.Some(ct) -> ct |> should.equal("application/json; charset=utf-8")
        option.None -> should.fail()
      }
      case body {
        transaction.Text(text) -> {
          string.contains(text, "error") |> should.equal(True)
          string.contains(text, "age") |> should.equal(True)
          string.contains(text, "Int") |> should.equal(True)
          string.contains(text, "String") |> should.equal(True)
        }
        _ -> should.fail()
      }
    }
  }
}

pub fn error_response_with_only_message_creates_json_with_message_only_test() {
  let error =
    ValidationError(
      message: "Unexpected end of JSON input",
      field: option.None,
      expected: option.None,
      found: option.None,
    )

  let response = error_response(error)

  case response {
    transaction.Response(status, body, _, _, _) -> {
      status |> should.equal(statuses.to_code(statuses.bad_request_status()))
      case body {
        transaction.Text(text) -> {
          string.contains(text, "error") |> should.equal(True)
          string.contains(text, "\"error\"") |> should.equal(True)
        }
        _ -> should.fail()
      }
    }
  }
}

pub fn error_response_status_code_is_bad_request_test() {
  let error =
    ValidationError(
      message: "Test error",
      field: option.None,
      expected: option.None,
      found: option.None,
    )

  let response = error_response(error)

  case response {
    transaction.Response(status, _, _, _, _) -> {
      status |> should.equal(statuses.to_code(statuses.bad_request_status()))
    }
  }
}

pub fn error_response_content_type_is_application_json_test() {
  let error =
    ValidationError(
      message: "Test error",
      field: option.None,
      expected: option.None,
      found: option.None,
    )

  let response = error_response(error)

  case response {
    transaction.Response(_, _, _, _, content_type) -> {
      case content_type {
        option.Some(ct) -> ct |> should.equal("application/json; charset=utf-8")
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_null_value_for_non_option_returns_error_test() {
  let decoder = decode.string
  let json_body = "null"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      error.message |> should.equal(error.message)
    }
  }
}

pub fn validate_with_empty_object_returns_error_for_missing_fields_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }
  let json_body = "{}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      string.contains(error.message, "name") |> should.equal(True)
      case error.field {
        option.Some(field) -> field |> should.equal("name")
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_empty_array_returns_empty_list_test() {
  let decoder = decode.list(decode.string)
  let json_body = "[]"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> {
      list.length(value) |> should.equal(0)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_with_deeply_nested_path_returns_full_path_test() {
  let decoder = {
    use level1 <- decode.field("level1", {
      use level2 <- decode.field("level2", {
        use level3 <- decode.field("level3", decode.int)
        decode.success(level3)
      })
      decode.success(level2)
    })
    decode.success(level1)
  }
  let json_body = "{\"level1\":{\"level2\":{\"level3\":\"not a number\"}}}"

  let result = validate(json_body, decoder)

  case result {
    Ok(_) -> should.fail()
    Error(error) -> {
      case error.field {
        option.Some(field) -> {
          string.contains(field, "level1") |> should.equal(True)
          string.contains(field, "level2") |> should.equal(True)
          string.contains(field, "level3") |> should.equal(True)
        }
        option.None -> should.fail()
      }
    }
  }
}

pub fn validate_with_special_characters_in_field_names_handles_correctly_test() {
  let decoder = {
    use field_name <- decode.field("field-name", decode.string)
    decode.success(field_name)
  }
  let json_body = "{\"field-name\":\"value\"}"

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> value |> should.equal("value")
    Error(_) -> should.fail()
  }
}

pub fn validate_with_unicode_characters_in_string_handles_correctly_test() {
  let decoder = decode.string
  let json_body = "\"Hello 世界\""

  let result = validate(json_body, decoder)

  case result {
    Ok(value) -> value |> should.equal("Hello 世界")
    Error(_) -> should.fail()
  }
}

pub fn validate_with_custom_type_decoder_returns_decoded_value_test() {
  let decoder = {
    use value <- decode.field("value", decode.string)
    decode.success(CustomType(value))
  }
  let json_body = "{\"value\":\"custom\"}"

  let result = validate(json_body, decoder)

  case result {
    Ok(CustomType(value)) -> value |> should.equal("custom")
    Error(_) -> should.fail()
  }
}

pub fn validate_or_respond_with_valid_json_returns_ok_test() {
  let decoder = decode.string
  let json_body = "\"hello\""

  let result = validate_or_respond(json_body, decoder)

  result
  |> should.be_ok
  |> should.equal("hello")
}

pub fn validate_or_respond_with_invalid_json_returns_error_response_test() {
  let decoder = decode.string
  let json_body = "invalid json"

  let result = validate_or_respond(json_body, decoder)

  result |> should.be_error
}

pub fn validate_or_respond_error_response_has_bad_request_status_test() {
  let decoder = decode.string
  let json_body = "invalid json"

  case validate_or_respond(json_body, decoder) {
    Error(response) -> {
      response.status |> should.equal(statuses.to_code(statuses.bad_request_status()))
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_or_respond_error_response_is_json_test() {
  let decoder = decode.string
  let json_body = "invalid json"

  case validate_or_respond(json_body, decoder) {
    Error(response) -> {
      case response.content_type {
        option.Some(ct) ->
          string.contains(ct, "application/json") |> should.equal(True)
        option.None -> should.fail()
      }
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_or_respond_with_wrong_type_returns_error_response_test() {
  let decoder = decode.int
  let json_body = "\"not an int\""

  case validate_or_respond(json_body, decoder) {
    Error(response) -> {
      case response.body {
        transaction.Text(text) ->
          string.contains(text, "Expected") |> should.equal(True)
        _ -> should.fail()
      }
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_or_respond_with_missing_field_returns_error_response_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(#(name, age))
  }
  let json_body = "{\"name\":\"Alice\"}"

  case validate_or_respond(json_body, decoder) {
    Error(response) -> {
      case response.body {
        transaction.Text(text) ->
          string.contains(text, "age") |> should.equal(True)
        _ -> should.fail()
      }
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_or_respond_with_complex_valid_data_returns_ok_test() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, age, email))
  }
  let json_body = "{\"name\":\"Bob\",\"age\":25,\"email\":\"bob@example.com\"}"

  let result = validate_or_respond(json_body, decoder)

  result
  |> should.be_ok
  |> should.equal(#("Bob", 25, "bob@example.com"))
}
