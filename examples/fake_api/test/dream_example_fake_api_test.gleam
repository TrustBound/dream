import contract_tests
import dream_test/reporters/bdd
import dream_test/runner
import envoy
import news_tests
import outputs_tests

/// The suites run first. The output checks run them again, so they wait
/// until the first run ends: both runs use the same ports.
pub fn main() {
  runner.new([news_tests.tests(), contract_tests.tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
  run_output_checks(envoy.get("NEWS_HEADLINES_URL"))
}

/// The output checks compare the reports with the outputs that the guide
/// shows. A run against the real service has another report, so it
/// leaves them out.
fn run_output_checks(real_service_url: Result(String, Nil)) -> Nil {
  case real_service_url {
    Ok(_url) -> Nil
    Error(Nil) -> {
      runner.new([outputs_tests.tests()])
      |> runner.default_timeout_ms(30_000)
      |> runner.results_reporters([bdd.new()])
      |> runner.exit_on_failure()
      |> runner.run()
      Nil
    }
  }
}
