import down_tests
import dream_test/reporters/bdd
import dream_test/runner
import envoy
import outputs_tests.{one_at_a_time}
import search_failure_tests
import search_tests
import write_tests

pub fn main() {
  runner.new([search_tests.tests(), search_failure_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [
    write_tests.tests(),
    down_tests.tests(),
  ])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The output checks compare the reports of a playback run with the
/// outputs that the guide shows, so a record run leaves them out.
fn output_checks() {
  case envoy.get("RECORDER_MODE") {
    Ok("record") -> []
    _ -> [outputs_tests.tests()]
  }
}
