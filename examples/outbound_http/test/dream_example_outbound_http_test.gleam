import dream_test/reporters/bdd
import dream_test/runner
import forecasts_tests

pub fn main() {
  runner.new([
    forecasts_tests.tests(),
    forecasts_tests.client_tests(),
    forecasts_tests.slow_service_tests(),
  ])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
