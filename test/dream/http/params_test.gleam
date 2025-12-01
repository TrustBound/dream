//// Tests for dream/http/params module.

import dream/http/params.{
  field_optional, require_field, require_field_int, require_form, require_int,
  require_string,
}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream_test/assertions/should.{
  be_none, be_ok, be_some, contain_string, equal, have_length, or_fail_with,
  should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import matchers/extract_error_message.{extract_error_message}
import matchers/extract_field.{extract_field}

// ============================================================================
// Helper Functions
// ============================================================================

fn create_params_request(
  params: List(#(String, String)),
  body: String,
) -> Request {
  Request(
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
      let request = create_params_request([#("id", "123")], "")

      require_int(request, "id")
      |> should()
      |> be_ok()
      |> equal(123)
      |> or_fail_with("Should return 123")
    }),
    it("returns error for missing parameter", fn() {
      let request = create_params_request([], "")

      require_int(request, "id")
      |> should()
      |> extract_error_message()
      |> contain_string("Missing")
      |> or_fail_with("Should mention 'Missing'")
    }),
    it("returns error for non-integer", fn() {
      let request = create_params_request([#("id", "abc")], "")

      require_int(request, "id")
      |> should()
      |> extract_error_message()
      |> contain_string("integer")
      |> or_fail_with("Should mention 'integer'")
    }),
    it("returns Ok with negative integer", fn() {
      let request = create_params_request([#("id", "-42")], "")

      require_int(request, "id")
      |> should()
      |> be_ok()
      |> equal(-42)
      |> or_fail_with("Should return -42")
    }),
    it("returns Ok with zero", fn() {
      let request = create_params_request([#("id", "0")], "")

      require_int(request, "id")
      |> should()
      |> be_ok()
      |> equal(0)
      |> or_fail_with("Should return 0")
    }),
    it("returns Ok with large integer", fn() {
      let request = create_params_request([#("id", "999999")], "")

      require_int(request, "id")
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
      let request = create_params_request([#("name", "john")], "")

      require_string(request, "name")
      |> should()
      |> be_ok()
      |> equal("john")
      |> or_fail_with("Should return 'john'")
    }),
    it("returns error for missing parameter", fn() {
      let request = create_params_request([], "")

      require_string(request, "name")
      |> should()
      |> extract_error_message()
      |> contain_string("Missing")
      |> or_fail_with("Should mention 'Missing'")
    }),
    it("returns Ok with empty string", fn() {
      let request = create_params_request([#("name", "")], "")

      require_string(request, "name")
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Should return empty string")
    }),
    it("returns Ok with special characters", fn() {
      let request = create_params_request([#("name", "user@example")], "")

      require_string(request, "name")
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
      let request = create_params_request([], "title=Hello&description=World")

      require_form(request)
      |> should()
      |> be_ok()
      |> have_length(2)
      |> or_fail_with("Should parse 2 fields")
    }),
    it("extracts title field correctly", fn() {
      let request = create_params_request([], "title=Hello&description=World")

      require_form(request)
      |> should()
      |> be_ok()
      |> extract_field("title")
      |> equal("Hello")
      |> or_fail_with("title should be 'Hello'")
    }),
    it("extracts description field correctly", fn() {
      let request = create_params_request([], "title=Hello&description=World")

      require_form(request)
      |> should()
      |> be_ok()
      |> extract_field("description")
      |> equal("World")
      |> or_fail_with("description should be 'World'")
    }),
    it("returns error for empty body", fn() {
      let request = create_params_request([], "")

      require_form(request)
      |> should()
      |> extract_error_message()
      |> contain_string("empty")
      |> or_fail_with("Should mention 'empty'")
    }),
    it("decodes URL-encoded space", fn() {
      let request = create_params_request([], "name=hello%20world")

      require_form(request)
      |> should()
      |> be_ok()
      |> extract_field("name")
      |> equal("hello world")
      |> or_fail_with("Should decode %20 as space")
    }),
    it("decodes URL-encoded email", fn() {
      let request = create_params_request([], "email=user%40example.com")

      require_form(request)
      |> should()
      |> be_ok()
      |> extract_field("email")
      |> equal("user@example.com")
      |> or_fail_with("Should decode %40 as @")
    }),
    it("decodes plus sign as space", fn() {
      let request = create_params_request([], "query=search+term")

      require_form(request)
      |> should()
      |> be_ok()
      |> extract_field("query")
      |> equal("search term")
      |> or_fail_with("Should decode + as space")
    }),
    it("handles single field", fn() {
      let request = create_params_request([], "title=Hello")

      require_form(request)
      |> should()
      |> be_ok()
      |> have_length(1)
      |> or_fail_with("Should parse 1 field")
    }),
    it("handles field without value", fn() {
      let request = create_params_request([], "flag&other=value")

      require_form(request)
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
      let form = [#("title", "Hello World")]

      require_field(form, "title")
      |> should()
      |> be_ok()
      |> equal("Hello World")
      |> or_fail_with("Should return 'Hello World'")
    }),
    it("returns error for missing field", fn() {
      let form = [#("other", "value")]

      require_field(form, "title")
      |> should()
      |> extract_error_message()
      |> contain_string("Missing required field")
      |> or_fail_with("Should mention 'Missing required field'")
    }),
    it("returns error for empty field", fn() {
      let form = [#("title", "")]

      require_field(form, "title")
      |> should()
      |> extract_error_message()
      |> contain_string("cannot be empty")
      |> or_fail_with("Should mention 'cannot be empty'")
    }),
    it("finds correct field among multiple", fn() {
      let form = [
        #("title", "Hello"),
        #("description", "World"),
        #("priority", "3"),
      ]

      require_field(form, "description")
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
      let form = [#("priority", "5")]

      require_field_int(form, "priority")
      |> should()
      |> be_ok()
      |> equal(5)
      |> or_fail_with("Should return 5")
    }),
    it("returns error for missing field", fn() {
      let form = [#("other", "value")]

      require_field_int(form, "priority")
      |> should()
      |> extract_error_message()
      |> contain_string("Missing required field")
      |> or_fail_with("Should mention 'Missing required field'")
    }),
    it("returns error for empty field", fn() {
      let form = [#("priority", "")]

      require_field_int(form, "priority")
      |> should()
      |> extract_error_message()
      |> contain_string("cannot be empty")
      |> or_fail_with("Should mention 'cannot be empty'")
    }),
    it("returns error for non-integer", fn() {
      let form = [#("priority", "abc")]

      require_field_int(form, "priority")
      |> should()
      |> extract_error_message()
      |> contain_string("must be an integer")
      |> or_fail_with("Should mention 'must be an integer'")
    }),
    it("returns Ok for negative integer", fn() {
      let form = [#("offset", "-10")]

      require_field_int(form, "offset")
      |> should()
      |> be_ok()
      |> equal(-10)
      |> or_fail_with("Should return -10")
    }),
    it("returns Ok for zero", fn() {
      let form = [#("count", "0")]

      require_field_int(form, "count")
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
      let form = [#("description", "Some text")]

      field_optional(form, "description")
      |> should()
      |> be_some()
      |> equal("Some text")
      |> or_fail_with("Should return 'Some text'")
    }),
    it("returns None for missing field", fn() {
      let form = [#("other", "value")]

      field_optional(form, "description")
      |> should()
      |> be_none()
      |> or_fail_with("Should return None")
    }),
    it("returns None for empty field", fn() {
      let form = [#("description", "")]

      field_optional(form, "description")
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty")
    }),
    it("returns None for empty form", fn() {
      field_optional([], "description")
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty form")
    }),
    it("returns Some for whitespace-only value", fn() {
      let form = [#("description", "   ")]

      field_optional(form, "description")
      |> should()
      |> be_some()
      |> equal("   ")
      |> or_fail_with("Should return whitespace string")
    }),
  ])
}
