//// Tests for dream/http/request module.

import dream/http/request.{
  type Request, type RequestBody, Bytes, Connect, Delete, Get, Head, Http, Http1,
  MalformedBody, Options, Other, Patch, Post, Put, Request, Stream, Text, Trace,
  body_as_string, get_int_param, get_param, get_query_param, get_string_param,
}
import dream/http/transaction
import dream_test/matchers.{
  be_equal, be_error, be_none, be_ok, be_some, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/bit_array
import gleam/list
import gleam/option
import gleam/yielder

// ============================================================================
// Helper Functions
// ============================================================================

fn create_test_request(body: String) -> Request {
  create_request_with_body(Text(body))
}

fn create_request_with_stream(stream: yielder.Yielder(BitArray)) -> Request {
  create_request_with_body(Stream(yielder.map(stream, Ok)))
}

fn create_request_with_body(body: RequestBody) -> Request {
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
    body: Text(""),
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

pub fn tests() -> TestSuite {
  describe("request", [
    body_as_string_tests(),
    get_param_tests(),
    get_int_param_tests(),
    get_string_param_tests(),
    get_query_param_tests(),
    method_tests(),
  ])
}

fn body_as_string_tests() -> UnitNode {
  group("body_as_string", [
    it("returns text body as string", fn() {
      // Arrange
      let request = create_test_request("test body")

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal("test body")
      |> or_fail_with("Should return body text")
    }),
    it("returns Bytes that are valid UTF-8 as a string", fn() {
      // Arrange
      let request = create_request_with_body(Bytes(<<"héllo":utf8>>))

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok("héllo"))
      |> or_fail_with("Should convert UTF-8 bytes to a string")
    }),
    it("returns Error(Nil) for Bytes that are not valid UTF-8", fn() {
      // Arrange
      let request = create_request_with_body(Bytes(<<0xFF, 0xD8, 0xFF, 0x00>>))

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(Nil))
      |> or_fail_with("Should return Error(Nil) for binary bytes")
    }),
    it("collects stream chunks to string", fn() {
      // Arrange
      let chunk1 = bit_array.from_string("Hello ")
      let chunk2 = bit_array.from_string("World")
      let stream = yielder.from_list([chunk1, chunk2])
      let request = create_request_with_stream(stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal("Hello World")
      |> or_fail_with("Should collect stream to string")
    }),
    it("returns empty string for empty stream", fn() {
      // Arrange
      let stream = yielder.empty()
      let request = create_request_with_stream(stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal("")
      |> or_fail_with("Should return empty string")
    }),
    it("returns error for invalid UTF-8 in stream", fn() {
      // Arrange
      let invalid_chunk = <<0xFF, 0xFF>>
      let stream = yielder.from_list([invalid_chunk])
      let request = create_request_with_stream(stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_error()
      |> or_fail_with("Should return error for invalid UTF-8")
    }),
    it("returns Error(Nil) when a read of the stream fails", fn() {
      // Arrange
      let items = [Ok(<<"Hello ":utf8>>), Error(MalformedBody)]
      let request = create_request_with_body(Stream(yielder.from_list(items)))

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(Nil))
      |> or_fail_with("A body that broke is not a string")
    }),
  ])
}

fn get_param_tests() -> UnitNode {
  group("get_param", [
    it("extracts value from param with format extension", fn() {
      // Arrange
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      // Act
      let result = get_param_value(request, "id")

      // Assert
      result
      |> should()
      |> be_equal("123")
      |> or_fail_with("Value should be '123'")
    }),
    it("preserves raw value with extension", fn() {
      // Arrange
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      // Act
      let result = get_param_raw(request, "id")

      // Assert
      result
      |> should()
      |> be_equal("123.json")
      |> or_fail_with("Raw should be '123.json'")
    }),
    it("extracts format from extension", fn() {
      // Arrange
      let request =
        create_request_with_params("/users/123.json", [#("id", "123.json")])

      // Act
      let result = get_param_format(request, "id")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("json")
      |> or_fail_with("Format should be 'json'")
    }),
  ])
}

fn get_int_param_tests() -> UnitNode {
  group("get_int_param", [
    it("returns Ok for valid integer", fn() {
      // Arrange
      let request = create_request_with_params("/users/123", [#("id", "123")])

      // Act
      let result = get_int_param(request, "id")

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal(123)
      |> or_fail_with("Should return 123")
    }),
    it("returns error for missing parameter", fn() {
      // Arrange
      let request = create_request_with_params("/users", [])

      // Act
      let result = get_int_param(request, "id")

      // Assert
      result
      |> should()
      |> be_error()
      |> be_equal("Missing required path parameter: id")
      |> or_fail_with("Should return missing error")
    }),
    it("returns error for non-integer", fn() {
      // Arrange
      let request = create_request_with_params("/users/abc", [#("id", "abc")])

      // Act
      let result = get_int_param(request, "id")

      // Assert
      result
      |> should()
      |> be_error()
      |> be_equal("id must be an integer")
      |> or_fail_with("Should return integer error")
    }),
  ])
}

fn get_string_param_tests() -> UnitNode {
  group("get_string_param", [
    it("returns Ok for valid parameter", fn() {
      // Arrange
      let request =
        create_request_with_params("/users/john", [#("name", "john")])

      // Act
      let result = get_string_param(request, "name")

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal("john")
      |> or_fail_with("Should return 'john'")
    }),
    it("returns error for missing parameter", fn() {
      // Arrange
      let request = create_request_with_params("/users", [])

      // Act
      let result = get_string_param(request, "name")

      // Assert
      result
      |> should()
      |> be_error()
      |> be_equal("Missing required path parameter: name")
      |> or_fail_with("Should return missing error")
    }),
  ])
}

fn get_query_param_tests() -> UnitNode {
  group("get_query_param", [
    it("keeps a value that contains an equals sign", fn() {
      // Arrange
      let query_string = "token=a=b"

      // Act
      let result = get_query_param(query_string, "token")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("a=b")
      |> or_fail_with("token should be 'a=b'")
    }),
    it("transaction version keeps a value that contains an equals sign", fn() {
      // Arrange
      let query_string = "token=a=b"

      // Act
      let result = transaction.get_query_param(query_string, "token")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("a=b")
      |> or_fail_with("token should be 'a=b'")
    }),
    it("decodes percent-encoded space", fn() {
      // Arrange
      let query_string = "name=hello%20world"

      // Act
      let result = get_query_param(query_string, "name")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("hello world")
      |> or_fail_with("Should decode %20 as space")
    }),
    it("decodes percent-encoded ampersand", fn() {
      // Arrange
      let query_string = "title=Buy%20milk%20%26%20eggs"

      // Act
      let result = get_query_param(query_string, "title")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("Buy milk & eggs")
      |> or_fail_with("Should decode %26 as &")
    }),
    it("decodes plus sign as space", fn() {
      // Arrange
      let query_string = "name=hello+world"

      // Act
      let result = get_query_param(query_string, "name")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("hello world")
      |> or_fail_with("Should decode + as space")
    }),
    it("decodes multiple encoded characters", fn() {
      // Arrange
      let query_string = "query=search%20for%20%22test%22"

      // Act
      let result = get_query_param(query_string, "query")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("search for \"test\"")
      |> or_fail_with("Should decode all percent-encoded chars")
    }),
    it("decodes both key and value", fn() {
      // Arrange
      let query_string = "user%20name=john%20doe"

      // Act
      let result = get_query_param(query_string, "user name")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("john doe")
      |> or_fail_with("Should decode key and value")
    }),
    it("handles empty value", fn() {
      // Arrange
      let query_string = "flag&other=value"

      // Act
      let result = get_query_param(query_string, "flag")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("")
      |> or_fail_with("Should return empty string for flag")
    }),
    it("finds parameter among multiple", fn() {
      // Arrange
      let query_string = "name=john&age=30&city=new%20york"

      // Act
      let result = get_query_param(query_string, "city")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("new york")
      |> or_fail_with("Should find city parameter")
    }),
    it("returns None for missing parameter", fn() {
      // Arrange
      let query_string = "name=john&age=30"

      // Act
      let result = get_query_param(query_string, "missing")

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should return None")
    }),
    it("returns None for empty query string", fn() {
      // Arrange
      let query_string = ""

      // Act
      let result = get_query_param(query_string, "name")

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should return None for empty query")
    }),
    it("decodes slash in value", fn() {
      // Arrange
      let query_string = "path=/home/user%2Fdocuments"

      // Act
      let result = get_query_param(query_string, "path")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("/home/user/documents")
      |> or_fail_with("Should decode %2F as /")
    }),
    it("handles malformed encoding gracefully", fn() {
      // Arrange
      let query_string = "name=hello%2"

      // Act
      let result = get_query_param(query_string, "name")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("hello%2")
      |> or_fail_with("Should fall back to original")
    }),
    it("decodes unicode characters", fn() {
      // Arrange
      let query_string = "text=hello%20%E2%9C%93"

      // Act
      let result = get_query_param(query_string, "text")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("hello ✓")
      |> or_fail_with("Should decode UTF-8")
    }),
    it("handles equals sign in value", fn() {
      // Arrange
      let query_string = "equation=x%3Dy%2Bz"

      // Act
      let result = get_query_param(query_string, "equation")

      // Assert
      result
      |> should()
      |> be_some()
      |> be_equal("x=y+z")
      |> or_fail_with("Should decode = in value")
    }),
  ])
}

fn method_tests() -> UnitNode {
  group("method names", [
    it("method_to_string names every method", fn() {
      // Arrange
      let methods = [Get, Post, Put, Delete, Patch, Options, Head]

      // Act
      let names = list.map(methods, request.method_to_string)

      // Assert
      names
      |> should()
      |> be_equal(["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
      |> or_fail_with("Each method should have its upper-case name")
    }),
    it("parse_method parses every method name in any case", fn() {
      // Arrange
      let names = ["get", "POST", "Put", "delete", "patch", "OPTIONS", "head"]

      // Act
      let methods = list.map(names, request.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([
        option.Some(Get),
        option.Some(Post),
        option.Some(Put),
        option.Some(Delete),
        option.Some(Patch),
        option.Some(Options),
        option.Some(Head),
      ])
      |> or_fail_with("Each method name should parse")
    }),
    it("method_to_string names CONNECT, TRACE and other methods", fn() {
      // Arrange
      let methods = [Connect, Trace, Other("PURGE"), Other("purge")]

      // Act
      let names = list.map(methods, request.method_to_string)

      // Assert
      names
      |> should()
      |> be_equal(["CONNECT", "TRACE", "PURGE", "purge"])
      |> or_fail_with("Other should keep its name exactly")
    }),
    it("parse_method parses CONNECT and TRACE in any case", fn() {
      // Arrange
      let names = ["CONNECT", "connect", "TRACE", "Trace"]

      // Act
      let methods = list.map(names, request.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([
        option.Some(Connect),
        option.Some(Connect),
        option.Some(Trace),
        option.Some(Trace),
      ])
      |> or_fail_with("CONNECT and TRACE should parse")
    }),
    it("parse_method gives Other with the exact name for another token", fn() {
      // Arrange
      let names = ["PURGE", "purge", "M-SEARCH"]

      // Act
      let methods = list.map(names, request.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([
        option.Some(Other("PURGE")),
        option.Some(Other("purge")),
        option.Some(Other("M-SEARCH")),
      ])
      |> or_fail_with("A token that is no standard method should be Other")
    }),
    it("parse_method returns None for text that is not a method token", fn() {
      // Arrange
      let names = ["", "GET /", "P(URGE"]

      // Act
      let methods = list.map(names, request.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([option.None, option.None, option.None])
      |> or_fail_with("Text that is not a token should not parse")
    }),
    it("get_query_param keeps a value that is not valid percent-encoding", fn() {
      // Arrange
      let query = "q=100%zz+off"

      // Act
      let result = get_query_param(query, "q")

      // Assert
      result
      |> should()
      |> be_equal(option.Some("100%zz off"))
      |> or_fail_with("An invalid escape should stay, with + as a space")
    }),
  ])
}
