//// Tests for dream/http/params module.

import dream/http/params.{
  field_optional, require_field, require_field_int, require_form, require_int,
  require_string,
}
import dream/http/request.{Get}
import dream_test/assertions/should.{
  be_none, be_ok, be_some, contain_string, equal, have_length, or_fail_with,
  should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import matchers/extract_error_message.{extract_error_message}
import matchers/extract_field.{extract_field}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("params", [
    require_int_tests(),
    require_string_tests(),
    require_form_tests(),
    require_field_tests(),
    require_field_int_tests(),
    field_optional_tests(),
  ])
}

fn require_int_tests() -> UnitTest {
  describe("require_int", [
    it("returns Ok with valid integer", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [#("id", "123")])

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(123)
      |> or_fail_with("Should return 123")
    }),
    it("returns error for missing parameter", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/test")

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("Missing")
      |> or_fail_with("Should mention 'Missing'")
    }),
    it("returns error for non-integer", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [#("id", "abc")])

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("integer")
      |> or_fail_with("Should mention 'integer'")
    }),
    it("returns Ok with negative integer", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [#("id", "-42")])

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(-42)
      |> or_fail_with("Should return -42")
    }),
    it("returns Ok with zero", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [#("id", "0")])

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(0)
      |> or_fail_with("Should return 0")
    }),
    it("returns Ok with large integer", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [
          #("id", "999999"),
        ])

      // Act
      let result = require_int(request, "id")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(999_999)
      |> or_fail_with("Should return 999999")
    }),
  ])
}

fn require_string_tests() -> UnitTest {
  describe("require_string", [
    it("returns Ok with valid parameter", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [
          #("name", "john"),
        ])

      // Act
      let result = require_string(request, "name")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("john")
      |> or_fail_with("Should return 'john'")
    }),
    it("returns error for missing parameter", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/test")

      // Act
      let result = require_string(request, "name")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("Missing")
      |> or_fail_with("Should mention 'Missing'")
    }),
    it("returns Ok with empty string", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [#("name", "")])

      // Act
      let result = require_string(request, "name")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Should return empty string")
    }),
    it("returns Ok with special characters", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/test", [
          #("name", "user@example"),
        ])

      // Act
      let result = require_string(request, "name")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("user@example")
      |> or_fail_with("Should return 'user@example'")
    }),
  ])
}

fn require_form_tests() -> UnitTest {
  describe("require_form", [
    it("parses valid form body", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Get,
          "/test",
          "title=Hello&description=World",
        )

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> have_length(2)
      |> or_fail_with("Should parse 2 fields")
    }),
    it("extracts title field correctly", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Get,
          "/test",
          "title=Hello&description=World",
        )

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("title")
      |> equal("Hello")
      |> or_fail_with("title should be 'Hello'")
    }),
    it("extracts description field correctly", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Get,
          "/test",
          "title=Hello&description=World",
        )

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("description")
      |> equal("World")
      |> or_fail_with("description should be 'World'")
    }),
    it("returns error for empty body", fn() {
      // Arrange
      let request = test_request.create_request_with_body(Get, "/test", "")

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("empty")
      |> or_fail_with("Should mention 'empty'")
    }),
    it("decodes URL-encoded space", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Get,
          "/test",
          "name=hello%20world",
        )

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("name")
      |> equal("hello world")
      |> or_fail_with("Should decode %20 as space")
    }),
    it("decodes URL-encoded email", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Get,
          "/test",
          "email=user%40example.com",
        )

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("email")
      |> equal("user@example.com")
      |> or_fail_with("Should decode %40 as @")
    }),
    it("decodes plus sign as space", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Get, "/test", "query=search+term")

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("query")
      |> equal("search term")
      |> or_fail_with("Should decode + as space")
    }),
    it("handles single field", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Get, "/test", "title=Hello")

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> have_length(1)
      |> or_fail_with("Should parse 1 field")
    }),
    it("handles field without value", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Get, "/test", "flag&other=value")

      // Act
      let result = require_form(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> extract_field("flag")
      |> equal("")
      |> or_fail_with("flag should be empty string")
    }),
  ])
}

fn require_field_tests() -> UnitTest {
  describe("require_field", [
    it("returns Ok for existing field", fn() {
      // Arrange
      let form = [#("title", "Hello World")]

      // Act
      let result = require_field(form, "title")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("Hello World")
      |> or_fail_with("Should return 'Hello World'")
    }),
    it("returns error for missing field", fn() {
      // Arrange
      let form = [#("other", "value")]

      // Act
      let result = require_field(form, "title")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("Missing required field")
      |> or_fail_with("Should mention 'Missing required field'")
    }),
    it("returns error for empty field", fn() {
      // Arrange
      let form = [#("title", "")]

      // Act
      let result = require_field(form, "title")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("cannot be empty")
      |> or_fail_with("Should mention 'cannot be empty'")
    }),
    it("finds correct field among multiple", fn() {
      // Arrange
      let form = [
        #("title", "Hello"),
        #("description", "World"),
        #("priority", "3"),
      ]

      // Act
      let result = require_field(form, "description")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("World")
      |> or_fail_with("Should return 'World'")
    }),
  ])
}

fn require_field_int_tests() -> UnitTest {
  describe("require_field_int", [
    it("returns Ok for valid integer", fn() {
      // Arrange
      let form = [#("priority", "5")]

      // Act
      let result = require_field_int(form, "priority")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(5)
      |> or_fail_with("Should return 5")
    }),
    it("returns error for missing field", fn() {
      // Arrange
      let form = [#("other", "value")]

      // Act
      let result = require_field_int(form, "priority")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("Missing required field")
      |> or_fail_with("Should mention 'Missing required field'")
    }),
    it("returns error for empty field", fn() {
      // Arrange
      let form = [#("priority", "")]

      // Act
      let result = require_field_int(form, "priority")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("cannot be empty")
      |> or_fail_with("Should mention 'cannot be empty'")
    }),
    it("returns error for non-integer", fn() {
      // Arrange
      let form = [#("priority", "abc")]

      // Act
      let result = require_field_int(form, "priority")

      // Assert
      result
      |> should()
      |> extract_error_message()
      |> contain_string("must be an integer")
      |> or_fail_with("Should mention 'must be an integer'")
    }),
    it("returns Ok for negative integer", fn() {
      // Arrange
      let form = [#("offset", "-10")]

      // Act
      let result = require_field_int(form, "offset")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(-10)
      |> or_fail_with("Should return -10")
    }),
    it("returns Ok for zero", fn() {
      // Arrange
      let form = [#("count", "0")]

      // Act
      let result = require_field_int(form, "count")

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal(0)
      |> or_fail_with("Should return 0")
    }),
  ])
}

fn field_optional_tests() -> UnitTest {
  describe("field_optional", [
    it("returns Some for existing field", fn() {
      // Arrange
      let form = [#("description", "Some text")]

      // Act
      let result = field_optional(form, "description")

      // Assert
      result
      |> should()
      |> be_some()
      |> equal("Some text")
      |> or_fail_with("Should return 'Some text'")
    }),
    it("returns None for missing field", fn() {
      // Arrange
      let form = [#("other", "value")]

      // Act
      let result = field_optional(form, "description")

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should return None")
    }),
    it("returns None for empty field", fn() {
      // Arrange
      let form = [#("description", "")]

      // Act
      let result = field_optional(form, "description")

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty")
    }),
    it("returns None for empty form", fn() {
      // Arrange
      let form = []

      // Act
      let result = field_optional(form, "description")

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty form")
    }),
    it("returns Some for whitespace-only value", fn() {
      // Arrange
      let form = [#("description", "   ")]

      // Act
      let result = field_optional(form, "description")

      // Assert
      result
      |> should()
      |> be_some()
      |> equal("   ")
      |> or_fail_with("Should return whitespace string")
    }),
  ])
}
