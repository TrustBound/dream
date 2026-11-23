import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import snippets/testing_guide_user_test as user_test
import snippets/testing_guide_users_controller_test as users_controller_test

pub fn main() {
  runner.new([users_controller_test.tests(), user_test.tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
