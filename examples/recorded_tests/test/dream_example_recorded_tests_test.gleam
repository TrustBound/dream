import dream_test/reporters/bdd
import dream_test/runner
import envoy
import outputs_tests.{one_at_a_time}
import recorded_http/parcels_tests
import recorded_queries/lists_tests

pub fn main() {
  runner.new([parcels_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [lists_tests.tests()])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The output checks compare the reports of a playback run with the
/// outputs that the guides show, so a record run leaves them out.
fn output_checks() {
  case envoy.get("RECORDER_MODE") {
    Ok("record") -> []
    _ -> [outputs_tests.tests()]
  }
}
