//// Free TCP ports for the snippet tests.

/// Asks the operating system for a free TCP port.
@external(erlang, "port_ffi", "free_port")
pub fn free_port() -> Int
