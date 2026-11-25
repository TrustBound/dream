import dream_test/reporters/bdd
import dream_test/runner
import jobs_tests

pub fn main() {
  runner.new([jobs_tests.tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
