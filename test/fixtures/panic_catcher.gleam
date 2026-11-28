//// Runs a function that can panic, so a test can check the panic message.

/// Calls `run`. Returns `Ok` with its value, or `Error` with the message of
/// the panic that it raised.
@external(erlang, "panic_ffi", "catch_panic")
pub fn catch_panic(run: fn() -> a) -> Result(a, String)
