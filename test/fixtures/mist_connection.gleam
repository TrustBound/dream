//// Mist connections and requests for tests that call dream's server code
//// without a running server. See `mist_connection_ffi.erl`.

import gleam/http
import gleam/http/request as http_request
import gleam/option
import mist.{type Connection}

/// The client end of a test socket.
pub type Socket

/// The registered name of a test factory supervisor.
pub type Factory

/// A connection whose socket is already closed. `data` is the part of the
/// body that mist read with the request head.
@external(erlang, "mist_connection_ffi", "closed_connection")
pub fn closed_connection(data: BitArray) -> Connection

/// A connection with an open socket that uses `factory` to start the process
/// of a chunked response. Close the returned client socket at the end.
@external(erlang, "mist_connection_ffi", "open_connection")
pub fn open_connection(
  data: BitArray,
  factory: Factory,
) -> #(Connection, Socket)

/// A connection from the IPv6 loopback address `::1`.
@external(erlang, "mist_connection_ffi", "ipv6_connection")
pub fn ipv6_connection() -> Result(#(Connection, Socket), String)

/// A connection that a client made from the IPv4 address 127.0.0.1 to an
/// IPv6 socket, so the server sees the IPv4-mapped address
/// `::ffff:127.0.0.1`.
@external(erlang, "mist_connection_ffi", "ipv4_mapped_connection")
pub fn ipv4_mapped_connection() -> Result(#(Connection, Socket), String)

/// A factory supervisor that refuses to start any child.
@external(erlang, "mist_connection_ffi", "start_refusing_factory")
pub fn start_refusing_factory() -> Factory

/// A factory supervisor that starts each child it is given.
@external(erlang, "mist_connection_ffi", "start_accepting_factory")
pub fn start_accepting_factory() -> Factory

@external(erlang, "mist_connection_ffi", "stop_factory")
pub fn stop_factory(factory: Factory) -> Nil

/// Closes the server end of the socket of `connection`, so each later
/// write on it fails. Closing it again does nothing.
@external(erlang, "mist_connection_ffi", "close_connection_socket")
pub fn close_connection_socket(connection: Connection) -> Nil

@external(erlang, "mist_connection_ffi", "close_socket")
pub fn close_socket(socket: Socket) -> Nil

/// A request for `path` with `method` and `headers` on `connection`.
pub fn request(
  connection: Connection,
  method: http.Method,
  path: String,
  headers: List(#(String, String)),
) -> http_request.Request(Connection) {
  http_request.Request(
    method: method,
    headers: headers,
    body: connection,
    scheme: http.Http,
    host: "localhost",
    port: option.None,
    path: path,
    query: option.None,
  )
}
