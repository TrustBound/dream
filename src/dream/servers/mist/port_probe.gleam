//// Internal port availability probe for Mist servers.
////
//// Uses a short TCP connect attempt to determine if a port is already in use.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/option
import gleam/result

@external(erlang, "gleam_stdlib", "identity")
fn to_dynamic(value: a) -> Dynamic

@external(erlang, "inet", "parse_ipv4_address")
fn parse_ipv4_address(
  value: charlist.Charlist,
) -> Result(#(Int, Int, Int, Int), atom.Atom)

@external(erlang, "gen_tcp", "connect")
fn tcp_connect(
  address: #(Int, Int, Int, Int),
  port: Int,
  options: List(Dynamic),
  timeout: Int,
) -> Result(Dynamic, Dynamic)

@external(erlang, "gen_tcp", "close")
fn tcp_close(socket: Dynamic) -> Result(Nil, Dynamic)

/// Check whether a port is already in use on the given interface.
///
/// This performs a short TCP connect attempt and returns `True` when a listener
/// is already bound, `False` otherwise. It defaults to `"localhost"` when no
/// interface is provided.
///
/// ## Parameters
///
/// - `interface`: The interface to check. Use `Some("127.0.0.1")`, `Some("0.0.0.0")`,
///   or `Some("localhost")`. Pass `None` to use `"localhost"`.
/// - `port`: The TCP port number to probe.
///
/// This function is intended for internal server startup checks.
///
/// ## Example
///
/// ```gleam
/// import gleam/option.{None}
/// import dream/servers/mist/port_probe
///
/// let in_use = port_probe.is_in_use(None, 3000)
/// ```
pub fn is_in_use(interface: option.Option(String), port: Int) -> Bool {
  let host = case interface {
    option.Some(value) -> value
    option.None -> "localhost"
  }

  let connect_options = [to_dynamic(#(atom.create("active"), False))]

  let ipv4_addr = case host {
    "localhost" | "127.0.0.1" | "0.0.0.0" -> Ok(#(127, 0, 0, 1))
    _ -> parse_ipv4_address(charlist.from_string(host))
  }

  ipv4_addr
  |> result.map(fn(address) {
    case tcp_connect(address, port, connect_options, 200) {
      Ok(socket) -> {
        let _ = tcp_close(socket)
        True
      }
      Error(_) -> False
    }
  })
  |> result.unwrap(False)
}
