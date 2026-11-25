import cache_tests
import dream_test/reporters/bdd
import dream_test/runner

pub fn main() {
  runner.new([cache_tests.tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
