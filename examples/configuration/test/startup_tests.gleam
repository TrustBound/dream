//// The links app at startup: each wrong setting stops it with a message
//// and exit status 1. Each test runs the app in a new VM with its own
//// environment, so the tests never change the environment of the test
//// run.

import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}
import gleam/list
import gleam/result
import startup.{first_line, read_output, run_app}

/// A directory with no `.env` file.
const no_env_file = "test/fixtures"

pub fn tests() -> TestSuite {
  describe("Startup", context.value(valid_settings()), [
    it("stops when SIGNING_KEY is not set", fn(settings) {
      let variables = remove_setting(settings, "SIGNING_KEY")

      let result = run_app(no_env_file, variables)

      result |> stop_with("missing_signing_key")
    }),
    it("stops when PORT is not a number", fn(settings) {
      let variables = list.key_set(settings, "PORT", "eighty")

      let result = run_app(no_env_file, variables)

      result |> stop_with("port_not_a_number")
    }),
    it("stops when PORT is out of range", fn(settings) {
      let variables = list.key_set(settings, "PORT", "70000")

      let result = run_app(no_env_file, variables)

      result |> stop_with("port_out_of_range")
    }),
    it("stops when SITE_URL has no scheme", fn(settings) {
      let variables = list.key_set(settings, "SITE_URL", "links.example.com")

      let result = run_app(no_env_file, variables)

      result |> stop_with("site_url_without_scheme")
    }),
    it("stops when SIGNING_KEY is too short", fn(settings) {
      let variables = list.key_set(settings, "SIGNING_KEY", "secret")

      let result = run_app(no_env_file, variables)

      result |> stop_with("signing_key_too_short")
    }),
    it("stops when a line of .env is not valid", fn(_settings) {
      let variables = []

      let result = run_app("test/fixtures/invalid_env_file", variables)

      result |> stop_with("invalid_env_file")
    }),
    it("starts with .env, and the environment wins over the file", fn(_) {
      let variables = [#("PORT", "4323")]

      let line = first_line("test/fixtures/with_env_file", variables)

      line |> show_output("startup")
    }),
  ])
}

/// Every setting, with a valid value.
fn valid_settings() -> List(#(String, String)) {
  [
    #("SITE_URL", "https://links.example.com"),
    #("SIGNING_KEY", "test-signing-key-0123456789abcdef"),
  ]
}

fn remove_setting(
  settings: List(#(String, String)),
  name: String,
) -> List(#(String, String)) {
  list.filter(settings, fn(setting) { setting.0 != name })
}

/// Passes when the app stopped with exit status 1 and printed
/// `test/outputs/<name>.txt`.
fn stop_with(
  result: #(Int, String),
  name: String,
) -> Result(AssertionResult, String) {
  use output <- result.try(read_output(name))
  result
  |> should
  |> be_equal(#(1, output))
  |> or_fail_with("the app should stop with status 1 and print " <> name)
}

/// Passes when `text` is `test/outputs/<name>.txt`.
fn show_output(text: String, name: String) -> Result(AssertionResult, String) {
  use output <- result.try(read_output(name))
  text
  |> should
  |> be_equal(output)
  |> or_fail_with("the app should print " <> name)
}
