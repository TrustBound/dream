//// Tests for dream/http/request module.

import dream/http/request.{
  type Request, Get, Http, Http1, Request, body_as_string, get_int_param,
  get_param, get_query_param, get_string_param,
}
import dream_test/assertions/should.{
  be_error, be_none, be_ok, be_some, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/bit_array
import gleam/option
import gleam/yielder

// ============================================================================
// Helper Functions
// ============================================================================

fn create_test_request(body: String) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/test",
    query: "",
    params: [],
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

fn create_request_with_stream(stream: yielder.Yielder(BitArray)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/test",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.Some(stream),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn create_request_with_params(
  path: String,
  params: List(#(String, String)),
) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: params,
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn get_param_value(request: Request, name: String) -> String {
  case get_param(request, name) {
    Ok(param) -> param.value
    Error(_) -> ""
  }
}

fn get_param_raw(request: Request, name: String) -> String {
  case get_param(request, name) {
    Ok(param) -> param.raw
    Error(_) -> ""
  }
}

fn get_param_format(request: Request, name: String) -> option.Option(String) {
  case get_param(request, name) {
    Ok(param) -> param.format
    Error(_) -> option.None
  }
}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("request", [
    body_as_string_tests(),
    get_param_tests(),
    get_int_param_tests(),
    get_string_param_tests(),
    get_query_param_tests(),
  ])
}

fn body_as_string_tests() -> UnitTest {
  describe("body_as_string", [
    it("returns text body as string", fn() {
      let request = create_test_request("test body")

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("test body")
      |> or_fail_with("Should return body text")
    }),
    it("collects stream chunks to string", fn() {
      let chunk1 = bit_array.from_string("Hello ")
      let chunk2 = bit_array.from_string("World")
      let stream = yielder.from_list([chunk1, chunk2])
      let request = create_request_with_stream(stream)

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("Hello World")
      |> or_fail_with("Should collect stream to string")
    }),
    it("returns empty string for empty stream", fn() {
      let stream = yielder.empty()
      let request = create_request_with_stream(stream)

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Should return empty string")
    }),
    it("returns error for invalid UTF-8 in stream", fn() {
      let invalid_chunk = <<0xFF, 0xFF>>
      let stream = yielder.from_list([invalid_chunk])
      let request = create_request_with_stream(stream)

      body_as_string(request)
      |> should()
      |> be_error()
      |> or_fail_with("Should return error for invalid UTF-8")
    }),
  ])
}

fn get_param_tests() -> UnitTest {
  describe("get_param", [
    it("extracts value from param with format extension", fn() {
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      get_param_value(request, "id")
      |> should()
      |> equal("123")
      |> or_fail_with("Value should be '123'")
    }),
    it("preserves raw value with extension", fn() {
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      get_param_raw(request, "id")
      |> should()
      |> equal("123.json")
      |> or_fail_with("Raw should be '123.json'")
    }),
    it("extracts format from extension", fn() {
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      get_param_format(request, "id")
      |> should()
      |> be_some()
      |> equal("json")
      |> or_fail_with("Format should be 'json'")
    }),
  ])
}

fn get_int_param_tests() -> UnitTest {
  describe("get_int_param", [
    it("returns Ok for valid integer", fn() {
      let request = create_request_with_params("/users/123", [#("id", "123")])

      get_int_param(request, "id")
      |> should()
      |> be_ok()
      |> equal(123)
      |> or_fail_with("Should return 123")
    }),
    it("returns error for missing parameter", fn() {
      let request = create_request_with_params("/users", [])

      get_int_param(request, "id")
      |> should()
      |> be_error()
      |> equal("Missing id parameter")
      |> or_fail_with("Should return missing error")
    }),
    it("returns error for non-integer", fn() {
      let request = create_request_with_params("/users/abc", [#("id", "abc")])

      get_int_param(request, "id")
      |> should()
      |> be_error()
      |> equal("id must be an integer")
      |> or_fail_with("Should return integer error")
    }),
  ])
}

fn get_string_param_tests() -> UnitTest {
  describe("get_string_param", [
    it("returns Ok for valid parameter", fn() {
      let request =
        create_request_with_params("/users/john", [#("name", "john")])

      get_string_param(request, "name")
      |> should()
      |> be_ok()
      |> equal("john")
      |> or_fail_with("Should return 'john'")
    }),
    it("returns error for missing parameter", fn() {
      let request = create_request_with_params("/users", [])

      get_string_param(request, "name")
      |> should()
      |> be_error()
      |> equal("Missing name parameter")
      |> or_fail_with("Should return missing error")
    }),
  ])
}

fn get_query_param_tests() -> UnitTest {
  describe("get_query_param", [
    it("decodes percent-encoded space", fn() {
      get_query_param("name=hello%20world", "name")
      |> should()
      |> be_some()
      |> equal("hello world")
      |> or_fail_with("Should decode %20 as space")
    }),
    it("decodes percent-encoded ampersand", fn() {
      get_query_param("title=Buy%20milk%20%26%20eggs", "title")
      |> should()
      |> be_some()
      |> equal("Buy milk & eggs")
      |> or_fail_with("Should decode %26 as &")
    }),
    it("decodes plus sign as space", fn() {
      get_query_param("name=hello+world", "name")
      |> should()
      |> be_some()
      |> equal("hello world")
      |> or_fail_with("Should decode + as space")
    }),
    it("decodes multiple encoded characters", fn() {
      get_query_param("query=search%20for%20%22test%22", "query")
      |> should()
      |> be_some()
      |> equal("search for \"test\"")
      |> or_fail_with("Should decode all percent-encoded chars")
    }),
    it("decodes both key and value", fn() {
      get_query_param("user%20name=john%20doe", "user name")
      |> should()
      |> be_some()
      |> equal("john doe")
      |> or_fail_with("Should decode key and value")
    }),
    it("handles empty value", fn() {
      get_query_param("flag&other=value", "flag")
      |> should()
      |> be_some()
      |> equal("")
      |> or_fail_with("Should return empty string for flag")
    }),
    it("finds parameter among multiple", fn() {
      get_query_param("name=john&age=30&city=new%20york", "city")
      |> should()
      |> be_some()
      |> equal("new york")
      |> or_fail_with("Should find city parameter")
    }),
    it("returns None for missing parameter", fn() {
      get_query_param("name=john&age=30", "missing")
      |> should()
      |> be_none()
      |> or_fail_with("Should return None")
    }),
    it("returns None for empty query string", fn() {
      get_query_param("", "name")
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty query")
    }),
    it("decodes slash in value", fn() {
      get_query_param("path=/home/user%2Fdocuments", "path")
      |> should()
      |> be_some()
      |> equal("/home/user/documents")
      |> or_fail_with("Should decode %2F as /")
    }),
    it("handles malformed encoding gracefully", fn() {
      get_query_param("name=hello%2", "name")
      |> should()
      |> be_some()
      |> equal("hello%2")
      |> or_fail_with("Should fall back to original")
    }),
    it("decodes unicode characters", fn() {
      get_query_param("text=hello%20%E2%9C%93", "text")
      |> should()
      |> be_some()
      |> equal("hello ✓")
      |> or_fail_with("Should decode UTF-8")
    }),
    it("handles equals sign in value", fn() {
      get_query_param("equation=x%3Dy%2Bz", "equation")
      |> should()
      |> be_some()
      |> equal("x=y+z")
      |> or_fail_with("Should decode = in value")
    }),
  ])
}
