//// The reports of the "Test your code" sections of the guides. Each test
//// runs the test suite of a guide snippet, formats its report as the bdd
//// reporter prints it (with every duration set to 0, so it is the same on
//// every run), and compares it with the output file that the guide shows.
//// It also checks that the app module of a snippet is the code of its
//// example.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type TestResult, TestResult}
import dream_test/unit.{type UnitNode, describe, it}
import gleam/list
import gleam/string
import simplifile
import snippets/guide_api_patterns_test
import snippets/guide_database_api_test
import snippets/guide_deployment_test
import snippets/guide_getting_started_test
import snippets/guide_http2_test
import snippets/guide_operating_test
import snippets/guide_request_data_test
import snippets/guide_responses_test
import snippets/guide_routing_scope_test
import snippets/guide_routing_test
import snippets/guide_sse_test
import snippets/guide_streaming_test
import snippets/guide_templates_test
import snippets/guide_testing_failing_test
import snippets/guide_websockets_test

pub fn tests() -> TestSuite {
  describe("Guide reports", [
    report_test(
      "guide_getting_started_report",
      guide_getting_started_test.tests,
    ),
    report_test("guide_routing_report", guide_routing_test.tests),
    report_test("guide_routing_scope_report", guide_routing_scope_test.tests),
    report_test("guide_request_data_report", guide_request_data_test.tests),
    report_test("guide_responses_report", guide_responses_test.tests),
    report_test("guide_database_api_report", guide_database_api_test.tests),
    report_test("guide_api_patterns_report", guide_api_patterns_test.tests),
    report_test("guide_templates_report", guide_templates_test.tests),
    report_test("guide_streaming_report", guide_streaming_test.tests),
    report_test("guide_sse_report", guide_sse_test.tests),
    report_test("guide_websockets_report", guide_websockets_test.tests),
    report_test("guide_http2_report", guide_http2_test.tests),
    report_test("guide_deployment_report", guide_deployment_test.tests),
    report_test("guide_operating_report", guide_operating_test.tests),
    report_test(
      "guide_testing_failing_report",
      guide_testing_failing_test.tests,
    ),
    it("the getting started app is the code of examples/simplest", fn() {
      // Act
      let snippet = code_of("test/snippets/guide_getting_started_app.gleam")

      // Assert
      snippet
      |> should
      |> be_equal(code_of("examples/simplest/src/main.gleam"))
      |> or_fail_with("the snippet app should be the example's main.gleam")
    }),
    it("the responses visit counter is the code of examples/simple", fn() {
      // Act
      let snippet = code_of("test/snippets/guide_responses_visits.gleam")

      // Assert
      snippet
      |> should
      |> be_equal(code_of(
        "examples/simple/src/controllers/visits_controller.gleam",
      ))
      |> or_fail_with("the snippet should be the example's visits_controller")
    }),
  ])
}

/// Runs the suite of a guide snippet and compares its report with
/// test/outputs/<name>.txt
fn report_test(name: String, suite: fn() -> TestSuite) -> UnitNode {
  it(name <> " is the report of the guide's test", fn() {
    // Act
    let report = report_of(suite())

    // Assert
    report
    |> should
    |> be_equal(expected(name))
    |> or_fail_with("expected test/outputs/" <> name <> ".txt")
  })
}

/// The report of a suite as the bdd reporter formats it, with no times
fn report_of(suite: TestSuite) -> String {
  let report =
    runner.new([suite])
    |> runner.silent()
    |> runner.run()
  let tests = list.map(types.report_tests(report), without_duration)

  types.run_report(
    tests: tests,
    hook_failures: types.report_hook_failures(report),
    reporter_crashes: types.report_reporter_crashes(report),
  )
  |> bdd.format()
}

fn without_duration(result: TestResult) -> TestResult {
  TestResult(..result, duration_ms: 0)
}

fn expected(name: String) -> String {
  case simplifile.read("test/outputs/" <> name <> ".txt") {
    Ok(text) -> text
    Error(_) -> "test/outputs/" <> name <> ".txt is missing"
  }
}

/// The lines of a Gleam file after its module comment
fn code_of(path: String) -> String {
  case simplifile.read(path) {
    Ok(text) -> drop_module_comment(text)
    Error(_) -> path <> " is missing"
  }
}

fn drop_module_comment(text: String) -> String {
  string.split(text, "\n")
  |> list.drop_while(fn(line) { string.starts_with(line, "////") })
  |> string.join("\n")
}
