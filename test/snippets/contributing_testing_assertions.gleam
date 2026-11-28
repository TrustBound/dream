//// Assertions in dream_test. Shown in docs/contributing/testing.md.

import dream/http/error.{NotFound}
import dream/http/params
import dream/http/request.{Get}
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_none, be_ok, be_some, be_true, contain,
  contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/int
import gleam/option.{Some}

pub fn tests() -> UnitTest {
  describe("assertions", [
    it("checks one value", fn() {
      // All assertions follow the pattern:
      // value |> should() |> matcher() |> or_fail_with("message")
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
    it("chains matchers", fn() {
      let request =
        test_request.create_request_with_params(Get, "/users/42", [
          #("id", "42"),
        ])

      // Matchers can be chained:
      params.require_int(request, "id")
      |> should()
      |> be_ok()
      |> equal(42)
      |> or_fail_with("Expected id 42")
    }),
    other_matcher_tests(),
  ])
}

fn other_matcher_tests() -> UnitTest {
  describe("other matchers", [
    it("be_empty", fn() {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Expected an empty list")
    }),
    it("be_error", fn() {
      int.parse("eighty")
      |> should()
      |> be_error()
      |> equal(Nil)
      |> or_fail_with("Expected Error(Nil)")
    }),
    it("be_false", fn() {
      int.is_even(3)
      |> should()
      |> be_false()
      |> or_fail_with("Expected False")
    }),
    it("be_none", fn() {
      option.from_result(int.parse("eighty"))
      |> should()
      |> be_none()
      |> or_fail_with("Expected None")
    }),
    it("be_some", fn() {
      Some(8080)
      |> should()
      |> be_some()
      |> equal(8080)
      |> or_fail_with("Expected Some(8080)")
    }),
    it("be_true", fn() {
      int.is_even(4)
      |> should()
      |> be_true()
      |> or_fail_with("Expected True")
    }),
    it("contain", fn() {
      ["Ada", "Grace"]
      |> should()
      |> contain("Ada")
      |> or_fail_with("Expected the list to contain Ada")
    }),
    it("contain_string", fn() {
      "Hello, Ada!"
      |> should()
      |> contain_string("Ada")
      |> or_fail_with("Expected the text to contain Ada")
    }),
  ])
}
