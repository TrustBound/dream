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
/// ### Check a port <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_port_probe.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/port_probe
/// import gleam/option.{None}
///
/// pub fn check_port(port: Int) -> Bool {
///   let in_use = port_probe.is_in_use(None, port)
///   in_use
/// }
/// ```
pub fn is_in_use(interface: option.Option(String), port: Int) -> Bool {
  let host = case interface {
    option.Some(value) -> value
    option.None -> "localhost"
  }

  let connect_options = [to_dynamic(#(atom.create("active"), False))]

  let ipv4_address = case host {
    "localhost" | "127.0.0.1" | "0.0.0.0" -> Ok(#(127, 0, 0, 1))
    _ -> parse_ipv4_address(charlist.from_string(host))
  }

  ipv4_address
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
