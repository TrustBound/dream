//// Runs the links app in a new VM with the environment of a test. The
//// environment of the test run does not change.

/// Runs the app in `directory` with `variables`, and gives its exit status
/// and its output.
@external(erlang, "startup_ffi", "run_app")
pub fn run_app(
  directory: String,
  variables: List(#(String, String)),
) -> #(Int, String)

/// Runs the app in `directory` with `variables`, gives its first line of
/// output, and stops it.
@external(erlang, "startup_ffi", "first_line")
pub fn first_line(
  directory: String,
  variables: List(#(String, String)),
) -> String

/// The text of `test/outputs/<name>.txt`.
@external(erlang, "startup_ffi", "read_output")
pub fn read_output(name: String) -> Result(String, String)
