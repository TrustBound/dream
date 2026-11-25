//// Compares the outputs that the guides show, under `test/outputs/`, with
//// the real reports of the suites in playback mode, and checks that no
//// recording holds a secret. The times differ from run to run, so the
//// check leaves them out of both texts.

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
import recorded_http/miss_tests as http_miss_tests
import recorded_http/parcels_tests
import recorded_queries/lists_tests
import recorded_queries/miss_tests as query_miss_tests
import simplifile

pub fn tests() -> TestSuite {
  describe("The outputs in the guides", [
    it("shows the report of the parcels suite", fn() {
      runner.new([parcels_tests.tests()])
      |> matches_output("http_playback")
    }),
    it("shows the report of requests with no recording", fn() {
      runner.new([http_miss_tests.tests()])
      |> matches_output("http_miss")
    }),
    it("shows the report of the lists suite", fn() {
      runner.new([])
      |> runner.add_suites_with_config(one_at_a_time(), [lists_tests.tests()])
      |> matches_output("queries_playback")
    }),
    it("shows the report of a query with no recording", fn() {
      runner.new([query_miss_tests.tests()])
      |> matches_output("queries_miss")
    }),
    it("keeps the carrier token out of the HTTP recordings", fn() {
      use text <- result.try(read_directory("test/recordings/carrier"))
      #(
        string.contains(string.lowercase(text), "authorization"),
        string.contains(text, "test-carrier-token"),
      )
      |> should
      |> be_equal(#(False, False))
      |> or_fail_with("no HTTP recording should hold the token")
    }),
    it("keeps the share tokens out of the query recording", fn() {
      use text <- result.try(read_directory("test/recordings/queries"))
      string.contains(text, "{\"tuple\":[\"[hidden]\"]}")
      |> should
      |> be_equal(True)
      |> or_fail_with("the recording should hold [hidden] for the token")
    }),
  ])
}

/// The lists tests share one database, so they run one at a time, in
/// order.
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
  |> list.map(fn(line) {
    case
      string.starts_with(line, "Summary: "),
      string.split_once(line, " in ")
    {
      True, Ok(#(counts, _time)) -> counts <> " in 0ms"
      _, _ -> without_test_time(line)
    }
  })
  |> string.join("\n")
}

// A test line ends with its time in brackets, such as ` (12ms)` or
// ` (1.2s)`, when the test took 1ms or more
fn without_test_time(line: String) -> String {
  case string.ends_with(line, "ms)") || string.ends_with(line, "s)") {
    False -> line
    True ->
      case string.split(line, " (") |> list.reverse {
        [time, ..rest] ->
          case is_time(string.drop_end(time, 1)) {
            True -> rest |> list.reverse |> string.join(" (")
            False -> line
          }
        [] -> line
      }
  }
}

fn is_time(text: String) -> Bool {
  case string.first(text) {
    Ok(first) -> string.contains("0123456789", first)
    Error(Nil) -> False
  }
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
