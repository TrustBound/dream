import dream_test/reporters/bdd
import dream_test/runner
import share_tests
import startup_tests

pub fn main() {
  runner.new([
    share_tests.tests(),
    share_tests.local_tests(),
    startup_tests.tests(),
  ])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
