import dream/http/request.{get_query_param}
import dream_test/matchers.{
  be_empty, be_equal, be_error, be_false, be_none, be_ok, be_some, be_true,
  contain, contain_string, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/string

pub fn tests() -> TestSuite {
  describe("basic matchers", [
    // Equality
    it("equal", fn() {
      string.length("Alice")
      |> should()
      |> be_equal(5)
      |> or_fail_with("Should have 5 letters")
    }),
    // Boolean
    it("be_true", fn() {
      string.is_empty("")
      |> should()
      |> be_true()
      |> or_fail_with("Should be empty")
    }),
    it("be_false", fn() {
      list.is_empty([1])
      |> should()
      |> be_false()
      |> or_fail_with("Should not be empty")
    }),
    // Options
    it("be_some", fn() {
      get_query_param("page=2", "page")
      |> should()
      |> be_some()
      |> or_fail_with("Should find page")
    }),
    it("be_none", fn() {
      get_query_param("page=2", "sort")
      |> should()
      |> be_none()
      |> or_fail_with("Should not find sort")
    }),
    // Results
    it("be_ok", fn() {
      int.parse("42")
      |> should()
      |> be_ok()
      |> or_fail_with("Should parse 42")
    }),
    it("be_error", fn() {
      int.parse("forty-two")
      |> should()
      |> be_error()
      |> or_fail_with("Should not parse words")
    }),
    // Collections
    it("contain", fn() {
      [1, 2, 3]
      |> should()
      |> contain(2)
      |> or_fail_with("Should contain 2")
    }),
    it("be_empty", fn() {
      list.filter([1, 2, 3], fn(number) { number > 5 })
      |> should()
      |> be_empty()
      |> or_fail_with("Should find no numbers above 5")
    }),
    // Strings
    it("contain_string", fn() {
      string.uppercase("hello world")
      |> should()
      |> contain_string("WORLD")
      |> or_fail_with("Should contain WORLD")
    }),
  ])
}
