//// Tests for dream/http/transaction module.

import dream/http/request as dream_request
import dream/http/transaction.{
  type Request, Connect, Delete, Get, Head, Header, Options, Other, Patch, Post,
  Put, Trace,
}
import dream_test/matchers.{be_equal, be_false, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/list
import gleam/option.{None, Some}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("transaction", [
    header_tests(),
    cookie_tests(),
    method_tests(),
    query_tests(),
    request_tests(),
    param_tests(),
  ])
}

fn header_tests() -> UnitNode {
  group("get_header", [
    it("returns None for an empty header list", fn() {
      // Arrange
      let headers = []

      // Act
      let result = transaction.get_header(headers, "Accept")

      // Assert
      result
      |> should()
      |> be_equal(None)
      |> or_fail_with("An empty header list has no Accept header")
    }),
    it("skips headers with other names", fn() {
      // Arrange
      let headers = [
        Header("Content-Type", "text/plain"),
        Header("Accept", "text/html"),
      ]

      // Act
      let result = transaction.get_header(headers, "accept")

      // Assert
      result
      |> should()
      |> be_equal(Some("text/html"))
      |> or_fail_with("Should find Accept after Content-Type")
    }),
  ])
}

fn cookie_tests() -> UnitNode {
  group("cookies", [
    it("get_cookie returns None for an empty cookie list", fn() {
      // Arrange
      let cookies = []

      // Act
      let result = transaction.get_cookie(cookies, "session")

      // Assert
      result
      |> should()
      |> be_equal(None)
      |> or_fail_with("An empty cookie list has no session cookie")
    }),
    it("get_cookie_value returns None for a missing cookie", fn() {
      // Arrange
      let cookies = [transaction.simple_cookie("theme", "dark")]

      // Act
      let result = transaction.get_cookie_value(cookies, "session")

      // Assert
      result
      |> should()
      |> be_equal(None)
      |> or_fail_with("There is no session cookie")
    }),
  ])
}

fn method_tests() -> UnitNode {
  group("methods", [
    it("method_to_string names every method", fn() {
      // Arrange
      let methods = [Get, Post, Put, Delete, Patch, Options, Head]

      // Act
      let names = list.map(methods, transaction.method_to_string)

      // Assert
      names
      |> should()
      |> be_equal(["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
      |> or_fail_with("Each method should have its upper-case name")
    }),
    it("parse_method parses every method name", fn() {
      // Arrange
      let names = ["get", "POST", "Put", "delete", "patch", "OPTIONS", "head"]

      // Act
      let methods = list.map(names, transaction.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([
        Some(Get),
        Some(Post),
        Some(Put),
        Some(Delete),
        Some(Patch),
        Some(Options),
        Some(Head),
      ])
      |> or_fail_with("Each method name should parse, in any case")
    }),
    it("method_to_string names CONNECT, TRACE and other methods", fn() {
      // Arrange
      let methods = [Connect, Trace, Other("PURGE"), Other("purge")]

      // Act
      let names = list.map(methods, transaction.method_to_string)

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
      let methods = list.map(names, transaction.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([Some(Connect), Some(Connect), Some(Trace), Some(Trace)])
      |> or_fail_with("CONNECT and TRACE should parse")
    }),
    it("parse_method gives Other with the exact name for another token", fn() {
      // Arrange
      let names = ["BREW", "brew"]

      // Act
      let methods = list.map(names, transaction.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([Some(Other("BREW")), Some(Other("brew"))])
      |> or_fail_with("A token that is no standard method should be Other")
    }),
    it("parse_method returns None for text that is not a method token", fn() {
      // Arrange
      let names = ["", "GET /"]

      // Act
      let methods = list.map(names, transaction.parse_method)

      // Assert
      methods
      |> should()
      |> be_equal([None, None])
      |> or_fail_with("Text that is not a token should not parse")
    }),
  ])
}

fn query_tests() -> UnitNode {
  group("get_query_param", [
    it("returns None when no parameter has the name", fn() {
      // Arrange
      let query = "page=2&sort=name"

      // Act
      let result = transaction.get_query_param(query, "limit")

      // Assert
      result
      |> should()
      |> be_equal(None)
      |> or_fail_with("There is no limit parameter")
    }),
    it("finds a parameter after others", fn() {
      // Arrange
      let query = "page=2&sort=name"

      // Act
      let result = transaction.get_query_param(query, "sort")

      // Assert
      result
      |> should()
      |> be_equal(Some("name"))
      |> or_fail_with("sort should be name")
    }),
    it("returns an empty value for a parameter without =", fn() {
      // Arrange
      let query = "page=2&debug"

      // Act
      let result = transaction.get_query_param(query, "debug")

      // Assert
      result
      |> should()
      |> be_equal(Some(""))
      |> or_fail_with("debug has no value")
    }),
    it("keeps a value that is not valid percent-encoding", fn() {
      // Arrange
      let query = "q=100%zz+off"

      // Act
      let result = transaction.get_query_param(query, "q")

      // Assert
      result
      |> should()
      |> be_equal(Some("100%zz off"))
      |> or_fail_with("An invalid escape should stay, with + as a space")
    }),
  ])
}

fn request_tests() -> UnitNode {
  group("has_content_type", [
    it("returns False for a request without a content type", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let result = transaction.has_content_type(request, "application/json")

      // Assert
      result
      |> should()
      |> be_false()
      |> or_fail_with("A request without a content type has no JSON type")
    }),
  ])
}

fn param_tests() -> UnitNode {
  group("path parameters", [
    it("get_int_param reports a missing parameter", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let result = transaction.get_int_param(request, "id")

      // Assert
      result
      |> should()
      |> be_equal(Error("Missing required path parameter: id"))
      |> or_fail_with("A missing id should give the missing message")
    }),
    it("get_string_param reports a missing parameter", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let result = transaction.get_string_param(request, "name")

      // Assert
      result
      |> should()
      |> be_equal(Error("Missing required path parameter: name"))
      |> or_fail_with("A missing name should give the missing message")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn transaction_request(params: List(#(String, String))) -> Request {
  transaction.Request(
    method: Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/users",
    query: "",
    params: params,
    host: None,
    port: None,
    remote_address: None,
    body: dream_request.Text(""),
    headers: [],
    cookies: [],
    content_type: None,
    content_length: None,
  )
}
