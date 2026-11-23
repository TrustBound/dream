import dream/context_test
import dream/router_test
import dream_test/reporters/bdd
import dream_test/runner

// ... other test modules

pub fn main() {
  runner.new([
    context_test.tests(),
    router_test.tests(),
    // ... other modules
  ])
  |> runner.results_reporters([bdd.new()])
  |> runner.run()
}
