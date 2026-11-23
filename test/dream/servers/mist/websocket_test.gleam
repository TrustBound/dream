//// Tests for dream/servers/mist/websocket module.
////
//// Each test starts a real dream server on a free port, talks to it with a
//// small WebSocket client (fixtures/websocket_client_ffi.erl), and stops the
//// server.

import dream/http/request.{type Request, Get}
import dream/http/response.{type Response}
import dream/router.{route, router}
import dream/servers/mist/server
import dream/servers/mist/websocket
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/option.{type Option, None}
import gleam/result
import gleam/string

const socket_timeout_ms = 2000

pub fn tests() -> TestSuite {
  describe("websocket", [
    it("gives a binary frame to the handler as BinaryMessage", fn() {
      // Arrange
      let port = free_port()
      let close_results = process.new_subject()

      // Act
      let reply = {
        use handle <- result.try(start_server(port, close_results))
        let reply =
          binary_exchange(port, "/socket", <<1, 2, 3>>, socket_timeout_ms)
        server.stop(handle)
        reply
      }

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(2, <<1, 2, 3>>)))
      |> or_fail_with("The handler should echo the bytes in a binary frame")
    }),
    it("send_text returns SocketClosed after the client went away", fn() {
      // Arrange
      let port = free_port()
      let close_results = process.new_subject()

      // Act
      let send_result = {
        use handle <- result.try(start_server(port, close_results))
        let closed = connect_and_close(port, "/socket", socket_timeout_ms)
        let send_result =
          result.try(closed, fn(_nil) {
            process.receive(close_results, socket_timeout_ms)
            |> result.replace_error("on_close did not run")
          })
        server.stop(handle)
        send_result
      }

      // Assert
      send_result
      |> should()
      |> be_equal(Ok(Error(websocket.SocketClosed)))
      |> or_fail_with("A send on a closed connection should fail")
    }),
  ])
}

// ============================================================================
// Server, router and controller
// ============================================================================

type CloseResults =
  Subject(Result(Nil, websocket.SendError))

fn start_server(
  port: Int,
  close_results: CloseResults,
) -> Result(server.ServerHandle, String) {
  let started =
    server.new()
    |> server.services(close_results)
    |> server.router(
      router()
      |> route(
        method: Get,
        path: "/socket",
        controller: socket_controller,
        middleware: [],
      ),
    )
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)

  result.map_error(started, fn(start_error) {
    "Failed to start server on port "
    <> int.to_string(port)
    <> ": "
    <> string.inspect(start_error)
  })
}

fn socket_controller(
  request: Request,
  _context,
  close_results: CloseResults,
) -> Response {
  websocket.upgrade_websocket(
    request,
    dependencies: close_results,
    on_init: keep_connection,
    on_message: echo_binary,
    on_close: send_after_close,
  )
}

fn keep_connection(
  connection: websocket.Connection,
  _close_results: CloseResults,
) -> #(websocket.Connection, Option(Selector(Nil))) {
  #(connection, None)
}

fn echo_binary(
  connection: websocket.Connection,
  message: websocket.Message(Nil),
  _same_connection: websocket.Connection,
  _close_results: CloseResults,
) -> websocket.Action(websocket.Connection, Nil) {
  case message {
    websocket.BinaryMessage(data) -> echo_data(connection, data)
    _ -> websocket.continue_connection(connection)
  }
}

fn echo_data(
  connection: websocket.Connection,
  data: BitArray,
) -> websocket.Action(websocket.Connection, Nil) {
  case websocket.send_binary(connection, data) {
    Ok(Nil) -> websocket.continue_connection(connection)
    Error(_send_error) -> websocket.stop_connection()
  }
}

/// Tries to send on the connection after it closed, and gives the result
/// to the test.
fn send_after_close(
  connection: websocket.Connection,
  close_results: CloseResults,
) -> Nil {
  process.send(close_results, websocket.send_text(connection, "bye"))
}

// ============================================================================
// Client
// ============================================================================

@external(erlang, "websocket_client_ffi", "binary_exchange")
fn binary_exchange(
  port: Int,
  path: String,
  data: BitArray,
  timeout_ms: Int,
) -> Result(#(Int, BitArray), String)

@external(erlang, "websocket_client_ffi", "connect_and_close")
fn connect_and_close(
  port: Int,
  path: String,
  timeout_ms: Int,
) -> Result(Nil, String)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
