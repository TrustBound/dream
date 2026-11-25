//// Compares the outputs that the guide shows, under `test/outputs/`,
//// with the real reports of the suites. The times differ from run to
//// run, so the check leaves them out of both texts.

import contract_tests
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import gleam/string
import news_tests
import simplifile

pub fn tests() -> TestSuite {
  describe("The outputs in the guide", [
    it("shows the report of the news suite", fn() {
      let report = render_report(news_tests.tests())

      report |> matches_output("news")
    }),
    it("shows the report of the contract suite", fn() {
      let report = render_report(contract_tests.tests())

      report |> matches_output("contract")
    }),
  ])
}

fn render_report(suite: TestSuite) -> String {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> fn(report) {
    bdd.render(
      config: reporter_types.BddReporterConfig(
        color: False,
        mode: reporter_types.BddFull,
      ),
      report: report,
    )
  }
  |> without_times
}

/// Compares `report` with `test/outputs/<name>.txt`.
fn matches_output(
  report: String,
  name: String,
) -> Result(AssertionResult, String) {
  use expected <- result.try(
    simplifile.read("test/outputs/" <> name <> ".txt")
    |> result.map_error(simplifile.describe_error),
  )
  report
  |> should
  |> be_equal(without_times(expected))
  |> or_fail_with("the report should match test/outputs/" <> name <> ".txt")
}

/// The report with the times left out: the time of each test, such as
/// ` (12ms)`, goes away, and the summary line ends with `in 0ms`.
fn without_times(report: String) -> String {
  report
  |> string.split("\n")
  |> list.map(line_without_time)
  |> string.join("\n")
}

fn line_without_time(line: String) -> String {
  case string.starts_with(line, "Summary: "), string.split_once(line, " in ") {
    True, Ok(#(counts, _time)) -> counts <> " in 0ms"
    _, _ -> without_test_time(line)
  }
}

// A test line ends with its time in brackets, such as ` (12ms)` or
// ` (1.2s)`, when the test took 1ms or more
fn without_test_time(line: String) -> String {
  case string.ends_with(line, "s)"), string.split(line, " (") |> list.reverse {
    True, [time, ..rest] if rest != [] -> keep_unless_time(line, time, rest)
    _, _ -> line
  }
}

fn keep_unless_time(line: String, time: String, rest: List(String)) -> String {
  case is_time(string.drop_end(time, 1)) {
    True -> rest |> list.reverse |> string.join(" (")
    False -> line
  }
}

fn is_time(text: String) -> Bool {
  case string.first(text) {
    Ok(first) -> string.contains("0123456789", first)
    Error(Nil) -> False
  }
}
