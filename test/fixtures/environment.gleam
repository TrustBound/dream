//// Runs test code with set environment variables, one test at a time.
////
//// The test runner runs tests in parallel, and every test on the node shares
//// one set of environment variables. `with_environment` holds a node-wide
//// lock while it sets the variables, runs the body and unsets them, so two
//// tests never see each other's values.

import envoy
import gleam/list
import gleam/option.{type Option, None, Some}

/// Sets each variable to its `Some` value and unsets each `None` variable,
/// runs `body`, then unsets every variable in the list.
pub fn with_environment(
  variables: List(#(String, Option(String))),
  body: fn() -> result,
) -> result {
  use <- with_lock
  list.each(variables, apply_variable)
  let result = body()
  list.each(variables, fn(variable) { envoy.unset(variable.0) })
  result
}

fn apply_variable(variable: #(String, Option(String))) -> Nil {
  case variable {
    #(name, Some(value)) -> envoy.set(name, value)
    #(name, None) -> envoy.unset(name)
  }
}

@external(erlang, "environment_ffi", "with_lock")
fn with_lock(body: fn() -> result) -> result
