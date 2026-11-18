import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/unit.{to_test_cases}
import gleam/io
import gleam/list
import snippets/testing_guide_user_test as user_test
import snippets/testing_guide_users_controller_test as users_controller_test

pub fn main() -> Nil {
  [
    to_test_cases("controllers/users", users_controller_test.tests()),
    to_test_cases("models/user", user_test.tests()),
  ]
  |> list.flatten
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()
}
