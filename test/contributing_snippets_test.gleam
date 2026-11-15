//// Tests for the snippets shown in docs/contributing/: contributing.md,
//// testing.md and tone-guide.md.

import dream/dream
import dream/http/request.{Get}
import dream/http/response.{binary_response, text_response}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type Status, type TestResult, AssertionFailure, CustomMatcherFailure,
  MatchFailed, MatchOk, Passed,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/list
import gleam/option.{Some}
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/contributing_documentation_example
import snippets/contributing_test_naming
import snippets/contributing_testing_assertions
import snippets/contributing_testing_benchmark
import snippets/contributing_testing_entry_point
import snippets/contributing_testing_fixtures
import snippets/contributing_testing_hooks
import snippets/contributing_testing_matcher
import snippets/contributing_testing_standards
import snippets/contributing_testing_structure
import snippets/tone_guide_api_reference_avoid
import snippets/tone_guide_api_reference_example
import snippets/tone_guide_code_example

pub fn tests() -> UnitTest {
  describe("contributing snippets", [
    contributing_tests(),
    testing_tests(),
    testing_standards_tests(),
    tone_guide_tests(),
  ])
}

fn contributing_tests() -> UnitTest {
  describe("contributing.md", [
    it("test naming snippet tests all pass", fn() {
      // Arrange
      let snippet_tests = contributing_test_naming.tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal([Passed, Passed, Passed])
      |> or_fail_with("Expected three passing tests")
    }),
    it("documented function example greets Ada", fn() {
      // Arrange
      let greet_ada = contributing_documentation_example.greet_ada

      // Act
      let response = greet_ada()

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, Ada!")
      |> or_fail_with("Expected the greeting for Ada")
    }),
  ])
}

fn testing_tests() -> UnitTest {
  describe("testing.md", [
    it("test structure snippet test passes", fn() {
      // Arrange
      let snippet_tests = contributing_testing_structure.tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal([Passed])
      |> or_fail_with("Expected one passing test")
    }),
    it("entry point main runs the tests with no failures", fn() {
      // Arrange
      let main = contributing_testing_entry_point.main

      // Act
      let results = main()

      // Assert
      runner.has_failures(results)
      |> should()
      |> equal(False)
      |> or_fail_with("Expected no failures")
    }),
    it("assertions snippet tests all pass", fn() {
      // Arrange
      let snippet_tests = contributing_testing_assertions.tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal(list.repeat(Passed, 10))
      |> or_fail_with("Expected ten passing tests")
    }),
    it("custom matcher extracts text from a Text body", fn() {
      // Arrange
      let result = MatchOk(text_response(200, "hello"))

      // Act
      let extracted = contributing_testing_matcher.extract_body_text(result)

      // Assert
      extracted
      |> should()
      |> equal(MatchOk("hello"))
      |> or_fail_with("Expected MatchOk(\"hello\")")
    }),
    it("custom matcher fails for a body that is not Text", fn() {
      // Arrange
      let result =
        MatchOk(binary_response(200, <<137, 80, 78, 71>>, "image/png"))

      // Act
      let extracted = contributing_testing_matcher.extract_body_text(result)

      // Assert
      extracted
      |> should()
      |> equal(non_text_body_failure())
      |> or_fail_with("Expected the non-text body failure")
    }),
    it("fixtures snippet shows home with the test handler", fn() {
      // Arrange
      let show_home = contributing_testing_fixtures.show_home

      // Act
      let response = show_home()

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("test")
      |> or_fail_with("Expected body \"test\"")
    }),
    it("fixtures snippet shows user 42 with the id handler", fn() {
      // Arrange
      let show_user = contributing_testing_fixtures.show_user

      // Act
      let response = show_user()

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("id: 42")
      |> or_fail_with("Expected body \"id: 42\"")
    }),
    it("lifecycle hooks snippet tests all pass", fn() {
      // Arrange
      let snippet_tests = contributing_testing_hooks.tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal([Passed, Passed])
      |> or_fail_with("Expected two passing tests")
    }),
    it("benchmark snippet test passes", fn() {
      // Arrange
      let snippet_tests = contributing_testing_benchmark.tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal([Passed])
      |> or_fail_with("Expected one passing benchmark")
    }),
  ])
}

fn testing_standards_tests() -> UnitTest {
  describe("testing.md standards", [
    it("focused tests all pass", fn() {
      // Arrange
      let snippet_tests = contributing_testing_standards.focused_tests()

      // Act
      let statuses = run_snippet_tests(snippet_tests)

      // Assert
      statuses
      |> should()
      |> equal([Passed, Passed])
      |> or_fail_with("Expected two passing tests")
    }),
    it("unfocused test passes", fn() {
      // Arrange
      let snippet_test = contributing_testing_standards.unfocused_test()

      // Act
      let statuses = run_snippet_tests(snippet_test)

      // Assert
      statuses
      |> should()
      |> equal([Passed])
      |> or_fail_with("Expected one passing test")
    }),
    it("nested case matcher extracts text from a Text body", fn() {
      // Arrange
      let result = MatchOk(text_response(200, "hello"))

      // Act
      let extracted = contributing_testing_standards.extract_text(result)

      // Assert
      extracted
      |> should()
      |> equal(MatchOk("hello"))
      |> or_fail_with("Expected MatchOk(\"hello\")")
    }),
    it("flat matcher extracts text from a Text body", fn() {
      // Arrange
      let result = MatchOk(text_response(200, "hello"))

      // Act
      let extracted = contributing_testing_standards.extract_body_text(result)

      // Assert
      extracted
      |> should()
      |> equal(MatchOk("hello"))
      |> or_fail_with("Expected MatchOk(\"hello\")")
    }),
    it("get_user_id returns 0 when the id param is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users")

      // Act
      let user_id = contributing_testing_standards.get_user_id(request)

      // Assert
      user_id
      |> should()
      |> equal(0)
      |> or_fail_with("Expected 0")
    }),
    it("show_user returns the error message when the id is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users")

      // Act
      let response = contributing_testing_standards.show_user(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Missing id parameter")
      |> or_fail_with("Expected \"Missing id parameter\"")
    }),
    it("show_user returns status 400 when the id is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users")

      // Act
      let response = contributing_testing_standards.show_user(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(400)
      |> or_fail_with("Expected status 400")
    }),
    it("show_user returns the user id", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/users/42", [
          #("id", "42"),
        ])

      // Act
      let response = contributing_testing_standards.show_user(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("User 42")
      |> or_fail_with("Expected \"User 42\"")
    }),
  ])
}

fn tone_guide_tests() -> UnitTest {
  describe("tone-guide.md", [
    it("match_path example extracts the id", fn() {
      // Arrange
      let match_user_path = tone_guide_api_reference_example.match_user_path

      // Act
      let result = match_user_path()

      // Assert
      result
      |> should()
      |> equal(Some([#("id", "123")]))
      |> or_fail_with("Expected Some([#(\"id\", \"123\")])")
    }),
    it("match_path with the bad comment extracts the id", fn() {
      // Arrange
      let pattern = "/users/:id"

      // Act
      let result =
        tone_guide_api_reference_avoid.match_path(pattern, "/users/123")

      // Assert
      result
      |> should()
      |> equal(Some([#("id", "123")]))
      |> or_fail_with("Expected Some([#(\"id\", \"123\")])")
    }),
    it("code example router returns 404 for every path", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          tone_guide_code_example.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(404)
      |> or_fail_with("Expected status 404")
    }),
  ])
}

fn run_snippet_tests(snippet_tests: UnitTest) -> List(Status) {
  unit.to_test_cases("snippet", snippet_tests)
  |> runner.run_all()
  |> list.map(status_of)
}

fn status_of(result: TestResult) -> Status {
  result.status
}

fn non_text_body_failure() -> types.MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_body_text",
    message: "Expected Text body",
    payload: Some(CustomMatcherFailure(
      actual: "Non-text body type",
      description: "Body is not Text",
    )),
  ))
}
