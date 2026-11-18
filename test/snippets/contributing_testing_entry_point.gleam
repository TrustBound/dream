import dream/context_test
import dream/router_test
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_all}
import dream_test/unit.{to_test_cases}
import gleam/io
import gleam/list

// ... other test modules

pub fn main() {
  [
    to_test_cases("dream/context", context_test.tests()),
    to_test_cases("dream/router", router_test.tests()),
    // ... other modules
  ]
  |> list.flatten
  |> run_all()
  |> report(io.println)
}
