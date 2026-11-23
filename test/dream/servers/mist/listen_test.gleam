//// Tests for the blocking `server.listen`, the placeholder handler of
//// `server.new`, and the stop helper in dream_mist_server_ffi.erl.

import dream/dream
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/router.{route, router}
import dream/servers/mist/port_probe
import dream/servers/mist/server
import dream_test/matchers.{be_equal, be_false, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/panic_catcher
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/result
import mist

const socket_timeout_ms = 2000

const wait_attempts = 100

const wait_step_ms = 20

pub fn tests() -> TestSuite {
  describe("server.listen", [
    listen_tests(),
    placeholder_handler_tests(),
    stop_supervisor_tests(),
  ])
}

fn listen_tests() -> UnitNode {
  group("listen", [
    it("serves requests while it blocks the calling process", fn() {
      // Arrange
      let port = free_port()
      let listener =
        process.spawn_unlinked(fn() {
          server.new()
          |> server.router(hello_router())
          |> server.bind("127.0.0.1")
          |> server.listen(port)
        })
      let ready = wait_for_port(port, True, wait_attempts)

      // Act
      let status_line = get_status_line(port)
      process.kill(listener)
      let stopped = wait_for_port(port, False, wait_attempts)

      // Assert
      #(ready, status_line, stopped)
      |> should()
      |> be_equal(#(True, Ok("HTTP/1.1 200"), True))
      |> or_fail_with("listen should serve until its process stops")
    }),
    it("panics with the start error when the port is in use", fn() {
      // Arrange
      let #(port, held) = hold_port()
      let app =
        server.new()
        |> server.router(hello_router())
        |> server.bind("127.0.0.1")

      // Act
      let result = panic_catcher.catch_panic(fn() { server.listen(app, port) })
      release_port(held)

      // Assert
      result
      |> should()
      |> be_equal(Error(
        "Failed to start server: InitFailed(\"Port "
        <> int.to_string(port)
        <> " already in use on 127.0.0.1. Stop the process using that port or choose a different one.\")",
      ))
      |> or_fail_with("listen should panic with the port-in-use message")
    }),
    it("panics when the server cannot bind its address", fn() {
      // Arrange
      // 192.0.2.1 is a documentation address (RFC 5737) that no host has, so
      // the listener cannot bind it. The supervisor of mist then fails with
      // reason shutdown, which gleam_otp gives as InitFailed("shutdown").
      let port = free_port()
      let app =
        server.new()
        |> server.router(hello_router())
        |> server.bind("192.0.2.1")

      // Act
      let result =
        call_trapping_exits(fn() {
          panic_catcher.catch_panic(fn() { server.listen(app, port) })
        })

      // Assert
      result
      |> should()
      |> be_equal(Error("Failed to start server: InitFailed(\"shutdown\")"))
      |> or_fail_with("listen should panic when the address is not local")
    }),
  ])
}

fn placeholder_handler_tests() -> UnitNode {
  group("server.new placeholder handler", [
    it("answers 404 when the mist builder runs without a router", fn() {
      // Arrange
      let port = free_port()
      let builder =
        server.new()
        |> dream.get_server(risks_understood: True)
        |> mist.bind("127.0.0.1")
        |> mist.port(port)

      // Act
      let status_line = {
        use started <- result.try(
          mist.start(builder)
          |> result.map_error(fn(_start_error) { "mist did not start" }),
        )
        let status_line = get_status_line(port)
        stop_supervisor(started.pid)
        status_line
      }

      // Assert
      status_line
      |> should()
      |> be_equal(Ok("HTTP/1.1 404"))
      |> or_fail_with("The placeholder handler should answer 404")
    }),
  ])
}

fn stop_supervisor_tests() -> UnitNode {
  group("stop_supervisor", [
    it("returns when the process stops with a reason other than normal", fn() {
      // Arrange
      let pid = start_failing_on_stop()

      // Act
      stop_supervisor(pid)

      // Assert
      is_alive(pid)
      |> should()
      |> be_false()
      |> or_fail_with("The process should be down when stop returns")
    }),
  ])
}

// ============================================================================
// Router and helpers
// ============================================================================

fn hello_router() {
  router()
  |> route(method: Get, path: "/", controller: hello, middleware: [])
}

fn hello(_request: Request, _context, _services) -> Response {
  text_response(200, "hello")
}

/// Sends `GET /` and returns the status line of the answer.
fn get_status_line(port: Int) -> Result(String, String) {
  let payload = <<
    "GET / HTTP/1.1\r\nhost: 127.0.0.1\r\nconnection: close\r\n\r\n":utf8,
  >>
  request_until_closed(port, payload, socket_timeout_ms)
  |> result.map_error(fn(_reason) { "request failed" })
  |> result.try(fn(received) {
    bit_array.slice(received, 0, 12)
    |> result.try(bit_array.to_string)
    |> result.replace_error("answer too short")
  })
}

/// Waits until the port is in use (`in_use` True) or free (`in_use` False).
/// Returns True when it is, and False when the attempts run out.
fn wait_for_port(port: Int, in_use: Bool, attempts: Int) -> Bool {
  case port_probe.is_in_use(Some("127.0.0.1"), port) == in_use, attempts {
    True, _ -> True
    False, 0 -> False
    False, _ -> {
      process.sleep(wait_step_ms)
      wait_for_port(port, in_use, attempts - 1)
    }
  }
}

pub type HeldPort

@external(erlang, "doc_server_ffi", "hold_port")
fn hold_port() -> #(Int, HeldPort)

@external(erlang, "doc_server_ffi", "release_port")
fn release_port(held: HeldPort) -> Nil

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, Dynamic)

@external(erlang, "port_ffi", "call_trapping_exits")
fn call_trapping_exits(run: fn() -> a) -> a

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "dream_mist_server_ffi", "stop_supervisor")
fn stop_supervisor(pid: process.Pid) -> Nil

@external(erlang, "stop_supervisor_ffi", "start_failing_on_stop")
fn start_failing_on_stop() -> process.Pid

@external(erlang, "stop_supervisor_ffi", "is_alive")
fn is_alive(pid: process.Pid) -> Bool
