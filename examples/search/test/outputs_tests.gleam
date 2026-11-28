//// Compares the outputs that the guide shows, under `test/outputs/`, with
//// the real reports of the suites in playback mode, and checks that the
//// recordings hold no times. The times of a report differ from run to
//// run, so the check leaves them out of both texts.

import down_tests
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner.{type RunBuilder}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import gleam/string
import search_tests
import simplifile

pub fn tests() -> TestSuite {
  describe("The outputs in the guide", [
    it("shows the report of the search suite", fn() {
      runner.new([search_tests.tests()])
      |> matches_output("search_playback")
    }),
    it("shows the report of the suite with search down", fn() {
      runner.new([])
      |> runner.add_suites_with_config(one_at_a_time(), [down_tests.tests()])
      |> matches_output("search_down")
    }),
    it("keeps the times out of the recordings", fn() {
      use search <- result.try(read_directory("test/recordings/notes_search"))
      use write <- result.try(read_directory("test/recordings/notes_write"))
      let text = search <> write

      #(
        string.contains(text, "[\"date\","),
        list.length(string.split(text, "took\\\":")),
        list.length(string.split(text, "took\\\":0,")),
      )
      |> should
      |> be_equal(#(False, 4, 4))
      |> or_fail_with("no recording should hold a date or a took time")
    }),
  ])
}

/// The suites whose note IDs follow the order of the tests run one test
/// at a time, in order.
pub fn one_at_a_time() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 10_000)
}

/// Compares the report of the suites with `test/outputs/<name>.txt`.
fn matches_output(builder: RunBuilder, name: String) {
  let report =
    builder
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
  |> list.map(without_time)
  |> string.join("\n")
}

fn without_time(line: String) -> String {
  case string.starts_with(line, "Summary: "), string.split_once(line, " in ") {
    True, Ok(#(counts, _time)) -> counts <> " in 0ms"
    _, _ -> without_test_time(line)
  }
}

// A test line ends with its time in brackets, such as ` (12ms)` or
// ` (1.2s)`, when the test took 1ms or more
fn without_test_time(line: String) -> String {
  case string.split(line, " (") |> list.reverse {
    [last, first, ..rest] -> drop_time(line, [first, ..rest], last)
    _ -> line
  }
}

fn drop_time(line: String, reversed_parts: List(String), last: String) {
  case is_time(last) {
    True -> reversed_parts |> list.reverse |> string.join(" (")
    False -> line
  }
}

fn is_time(text: String) -> Bool {
  string.ends_with(text, "s)")
  && string.contains("0123456789", string.slice(text, 0, 1))
}

fn read_directory(directory: String) -> Result(String, String) {
  use names <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(simplifile.describe_error),
  )
  names
  |> list.sort(string.compare)
  |> list.try_map(fn(name) {
    simplifile.read(directory <> "/" <> name)
    |> result.map_error(simplifile.describe_error)
  })
  |> result.map(string.concat)
}
