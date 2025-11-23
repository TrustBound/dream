//// Tests for Dream parameter validation utilities
////
//// Black box tests following arrange-act-assert pattern.
//// Tests verify behavior, not implementation details.

import dream/http/error.{BadRequest}
import dream/http/params.{
  field_optional, require_field, require_field_int, require_form, require_int,
  require_string,
}
import dream/http/request.{type Request, Get, Http, Http1}
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should

// Helper to create a minimal request
fn create_request(params: List(#(String, String)), body: String) -> Request {
  request.Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/test",
    query: "",
    params: params,
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: body,
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

// require_int tests

pub fn require_int_with_valid_integer_returns_ok_test() {
  // Arrange
  let request = create_request([#("id", "123")], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(id) -> id |> should.equal(123)
    Error(_) -> should.fail()
  }
}

pub fn require_int_with_missing_parameter_returns_bad_request_test() {
  // Arrange
  let request = create_request([], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "Missing") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn require_int_with_non_integer_returns_bad_request_test() {
  // Arrange
  let request = create_request([#("id", "abc")], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "integer") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn require_int_with_negative_integer_returns_ok_test() {
  // Arrange
  let request = create_request([#("id", "-42")], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(id) -> id |> should.equal(-42)
    Error(_) -> should.fail()
  }
}

pub fn require_int_with_zero_returns_ok_test() {
  // Arrange
  let request = create_request([#("id", "0")], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(id) -> id |> should.equal(0)
    Error(_) -> should.fail()
  }
}

pub fn require_int_with_large_integer_returns_ok_test() {
  // Arrange
  let request = create_request([#("id", "999999")], "")

  // Act
  case require_int(request, "id") {
    // Assert
    Ok(id) -> id |> should.equal(999_999)
    Error(_) -> should.fail()
  }
}

// require_string tests

pub fn require_string_with_valid_parameter_returns_ok_test() {
  // Arrange
  let request = create_request([#("name", "john")], "")

  // Act
  case require_string(request, "name") {
    // Assert
    Ok(name) -> name |> should.equal("john")
    Error(_) -> should.fail()
  }
}

pub fn require_string_with_missing_parameter_returns_bad_request_test() {
  // Arrange
  let request = create_request([], "")

  // Act
  case require_string(request, "name") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "Missing") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn require_string_with_empty_string_returns_ok_test() {
  // Arrange
  let request = create_request([#("name", "")], "")

  // Act
  case require_string(request, "name") {
    // Assert
    Ok(name) -> name |> should.equal("")
    Error(_) -> should.fail()
  }
}

pub fn require_string_with_special_characters_returns_ok_test() {
  // Arrange
  // Note: Path params split on '.' for format extensions, so we use a value without dots
  let request = create_request([#("name", "user@example")], "")

  // Act
  case require_string(request, "name") {
    // Assert
    Ok(name) -> name |> should.equal("user@example")
    Error(_) -> should.fail()
  }
}

// require_form tests

pub fn require_form_with_valid_body_returns_ok_test() {
  // Arrange
  let request = create_request([], "title=Hello&description=World")

  // Act
  case require_form(request) {
    // Assert
    Ok(form) -> {
      list.length(form) |> should.equal(2)
      case list.key_find(form, "title") {
        Ok(value) -> value |> should.equal("Hello")
        Error(_) -> should.fail()
      }
      case list.key_find(form, "description") {
        Ok(value) -> value |> should.equal("World")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn require_form_with_empty_body_returns_bad_request_test() {
  // Arrange
  let request = create_request([], "")

  // Act
  case require_form(request) {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) -> string.contains(msg, "empty") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn require_form_decodes_url_encoded_values_test() {
  // Arrange
  let request =
    create_request([], "name=hello%20world&email=user%40example.com")

  // Act
  case require_form(request) {
    // Assert
    Ok(form) -> {
      case list.key_find(form, "name") {
        Ok(value) -> value |> should.equal("hello world")
        Error(_) -> should.fail()
      }
      case list.key_find(form, "email") {
        Ok(value) -> value |> should.equal("user@example.com")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn require_form_decodes_plus_sign_as_space_test() {
  // Arrange
  let request = create_request([], "query=search+term")

  // Act
  case require_form(request) {
    // Assert
    Ok(form) -> {
      case list.key_find(form, "query") {
        Ok(value) -> value |> should.equal("search term")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn require_form_handles_single_field_test() {
  // Arrange
  let request = create_request([], "title=Hello")

  // Act
  case require_form(request) {
    // Assert
    Ok(form) -> {
      list.length(form) |> should.equal(1)
      case list.key_find(form, "title") {
        Ok(value) -> value |> should.equal("Hello")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn require_form_handles_field_without_value_test() {
  // Arrange
  let request = create_request([], "flag&other=value")

  // Act
  case require_form(request) {
    // Assert
    Ok(form) -> {
      case list.key_find(form, "flag") {
        Ok(value) -> value |> should.equal("")
        Error(_) -> should.fail()
      }
      case list.key_find(form, "other") {
        Ok(value) -> value |> should.equal("value")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// require_field tests

pub fn require_field_with_existing_field_returns_ok_test() {
  // Arrange
  let form = [#("title", "Hello World")]

  // Act
  case require_field(form, "title") {
    // Assert
    Ok(value) -> value |> should.equal("Hello World")
    Error(_) -> should.fail()
  }
}

pub fn field_with_missing_field_returns_bad_request_test() {
  // Arrange
  let form = [#("other", "value")]

  // Act
  case require_field(form, "title") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "Missing required field") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn field_with_empty_field_returns_bad_request_test() {
  // Arrange
  let form = [#("title", "")]

  // Act
  case require_field(form, "title") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "cannot be empty") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn field_with_multiple_fields_finds_correct_one_test() {
  // Arrange
  let form = [
    #("title", "Hello"),
    #("description", "World"),
    #("priority", "3"),
  ]

  // Act
  case require_field(form, "description") {
    // Assert
    Ok(value) -> value |> should.equal("World")
    Error(_) -> should.fail()
  }
}

// require_field_int tests

pub fn require_field_int_with_valid_integer_returns_ok_test() {
  // Arrange
  let form = [#("priority", "5")]

  // Act
  case require_field_int(form, "priority") {
    // Assert
    Ok(value) -> value |> should.equal(5)
    Error(_) -> should.fail()
  }
}

pub fn field_int_with_missing_field_returns_bad_request_test() {
  // Arrange
  let form = [#("other", "value")]

  // Act
  case require_field_int(form, "priority") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "Missing required field") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn field_int_with_empty_field_returns_bad_request_test() {
  // Arrange
  let form = [#("priority", "")]

  // Act
  case require_field_int(form, "priority") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "cannot be empty") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn field_int_with_non_integer_returns_bad_request_test() {
  // Arrange
  let form = [#("priority", "abc")]

  // Act
  case require_field_int(form, "priority") {
    // Assert
    Ok(_) -> should.fail()
    Error(BadRequest(msg)) ->
      string.contains(msg, "must be an integer") |> should.be_true()
    Error(_) -> should.fail()
  }
}

pub fn field_int_with_negative_integer_returns_ok_test() {
  // Arrange
  let form = [#("offset", "-10")]

  // Act
  case require_field_int(form, "offset") {
    // Assert
    Ok(value) -> value |> should.equal(-10)
    Error(_) -> should.fail()
  }
}

pub fn field_int_with_zero_returns_ok_test() {
  // Arrange
  let form = [#("count", "0")]

  // Act
  case require_field_int(form, "count") {
    // Assert
    Ok(value) -> value |> should.equal(0)
    Error(_) -> should.fail()
  }
}

// field_optional tests

pub fn field_optional_with_existing_field_returns_some_test() {
  // Arrange
  let form = [#("description", "Some text")]

  // Act
  let result = field_optional(form, "description")

  // Assert
  case result {
    option.Some(value) -> value |> should.equal("Some text")
    option.None -> should.fail()
  }
}

pub fn field_optional_with_missing_field_returns_none_test() {
  // Arrange
  let form = [#("other", "value")]

  // Act
  let result = field_optional(form, "description")

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> option.None |> should.be_none()
  }
}

pub fn field_optional_with_empty_field_returns_none_test() {
  // Arrange
  let form = [#("description", "")]

  // Act
  let result = field_optional(form, "description")

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> option.None |> should.be_none()
  }
}

pub fn field_optional_with_empty_form_returns_none_test() {
  // Arrange
  let form = []

  // Act
  let result = field_optional(form, "description")

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> option.None |> should.be_none()
  }
}

pub fn field_optional_with_whitespace_only_returns_some_test() {
  // Arrange
  let form = [#("description", "   ")]

  // Act
  let result = field_optional(form, "description")

  // Assert
  case result {
    option.Some(value) -> value |> should.equal("   ")
    option.None -> should.fail()
  }
}
