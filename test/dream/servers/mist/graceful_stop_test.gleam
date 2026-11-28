//// Tests for `server.stop_gracefully`, the plain `server.stop`, and the drain
//// on `SIGTERM`, against a real server on a free port.

import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/bit_array
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/list
import gleam/result
import gleam/string

const slow_request = "GET /slow HTTP/1.1\r\nhost: localhost\r\n\r\n"

const endless_request = "GET /endless HTTP/1.1\r\nhost: localhost\r\n\r\n"

const fast_request = "GET / HTTP/1.1\r\nhost: localhost\r\n\r\n"

// How long a test waits for a message before it fails
const timeout_ms = 3000

pub fn tests() -> TestSuite {
  describe("server stop", [
    stop_gracefully_tests(),
    stop_tests(),
    sigterm_tests(),
  ])
}

fn stop_gracefully_tests() -> UnitNode {
  group("stop_gracefully", [
    it("lets a running request finish with connection: close", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let response = request_in_background(port, slow_request)
      let _started = await_started(events)

      // Act
      let stopped = stop_gracefully_in_background(handle, timeout_ms)
      let _released = on_drain(events, fn() { Nil })
      let described =
        process.receive(response, timeout_ms) |> result.map(describe_response)
      let _stopped = process.receive(stopped, timeout_ms)

      // Assert
      described
      |> should()
      |> be_equal(Ok(#("HTTP/1.1 200 OK", "close", "slow done")))
      |> or_fail_with("The running request must get its full response")
    }),
    it("refuses a new connection during the drain", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let _response = request_in_background(port, slow_request)
      let _started = await_started(events)

      // Act
      let stopped = stop_gracefully_in_background(handle, timeout_ms)
      let connected = on_drain(events, fn() { connect(port) })
      let _stopped = process.receive(stopped, timeout_ms)

      // Assert
      connected
      |> should()
      |> be_equal(Ok("econnrefused"))
      |> or_fail_with("A new connection during the drain must be refused")
    }),
    it("closes an idle keep-alive connection while a request runs", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let idle = open_idle(port, fast_request)
      let _response = request_in_background(port, slow_request)
      let _started = await_started(events)

      // Act
      let stopped = stop_gracefully_in_background(handle, timeout_ms)
      let closed = on_drain(events, fn() { closed_within(idle, timeout_ms) })
      let _stopped = process.receive(stopped, timeout_ms)

      // Assert
      closed
      |> should()
      |> be_equal(Ok(True))
      |> or_fail_with("The idle connection must close before the request ends")
    }),
    it("cuts a request that runs past the limit, and returns at it", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let response = request_in_background(port, endless_request)
      let _started = await_started(events)

      // Act
      let started = now_ms()
      server.stop_gracefully(handle, within: 300)
      let elapsed = now_ms() - started

      // Assert
      #(process.receive(response, timeout_ms), elapsed >= 300 && elapsed < 1000)
      |> should()
      |> be_equal(#(Ok(<<>>), True))
      |> or_fail_with(
        "The request must get no bytes, and the stop must end at the limit",
      )
    }),
    it("returns at once when no request runs", fn() {
      // Arrange
      let port = free_port()
      let assert Ok(handle) = start(port, process.new_subject())

      // Act
      let started = now_ms()
      server.stop_gracefully(handle, within: timeout_ms)
      let elapsed = now_ms() - started

      // Assert
      { elapsed < 300 }
      |> should()
      |> be_equal(True)
      |> or_fail_with("A server without requests must stop at once")
    }),
    it("is safe after the server already stopped", fn() {
      // Arrange
      let port = free_port()
      let assert Ok(handle) = start(port, process.new_subject())
      server.stop(handle)

      // Act
      let result = server.stop_gracefully(handle, within: 300)

      // Assert
      result
      |> should()
      |> be_equal(Nil)
      |> or_fail_with("stop_gracefully on a stopped server must return Nil")
    }),
  ])
}

fn stop_tests() -> UnitNode {
  group("stop", [
    it("cuts a running request at once", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let response = request_in_background(port, endless_request)
      let _started = await_started(events)

      // Act
      let started = now_ms()
      server.stop(handle)
      let elapsed = now_ms() - started

      // Assert
      #(process.receive(response, timeout_ms), elapsed < 300)
      |> should()
      |> be_equal(#(Ok(<<>>), True))
      |> or_fail_with("stop must close the running request at once")
    }),
  ])
}

fn sigterm_tests() -> UnitNode {
  group("SIGTERM", [
    it("drains the server, then passes SIGTERM on", fn() {
      // Arrange
      let port = free_port()
      let events = process.new_subject()
      let assert Ok(handle) = start(port, events)
      let signals = process.new_subject()
      let manager = start_signal_manager(signals)
      drain_on_sigterm(manager, server_pid(handle))
      let response = request_in_background(port, slow_request)
      let _started = await_started(events)

      // Act
      notify(manager, atom.create("sigterm"))
      let _released = on_drain(events, fn() { Nil })
      let described =
        process.receive(response, timeout_ms) |> result.map(describe_response)
      let signal =
        process.receive(signals, timeout_ms) |> result.map(atom.to_string)
      stop_signal_manager(manager)

      // Assert
      #(described, signal)
      |> should()
      |> be_equal(#(
        Ok(#("HTTP/1.1 200 OK", "close", "slow done")),
        Ok("sigterm"),
      ))
      |> or_fail_with("SIGTERM must drain the server before it stops the VM")
    }),
    it("drains every server that listens", fn() {
      // Arrange
      let events = process.new_subject()
      let first_port = free_port()
      let assert Ok(first) = start(first_port, events)
      let second_port = free_port()
      let assert Ok(second) = start(second_port, events)
      let signals = process.new_subject()
      let manager = start_signal_manager(signals)
      drain_on_sigterm(manager, server_pid(first))
      drain_on_sigterm(manager, server_pid(second))
      let first_response = request_in_background(first_port, slow_request)
      let second_response = request_in_background(second_port, slow_request)
      let _first_started = await_started(events)
      let _second_started = await_started(events)

      // Act
      notify(manager, atom.create("sigterm"))
      let _first_released = on_drain(events, fn() { Nil })
      let _second_released = on_drain(events, fn() { Nil })
      let described =
        [first_response, second_response]
        |> list.map(fn(response) {
          process.receive(response, timeout_ms) |> result.map(describe_response)
        })
      let _signal = process.receive(signals, timeout_ms)
      stop_signal_manager(manager)

      // Assert
      described
      |> should()
      |> be_equal([
        Ok(#("HTTP/1.1 200 OK", "close", "slow done")),
        Ok(#("HTTP/1.1 200 OK", "close", "slow done")),
      ])
      |> or_fail_with("SIGTERM must drain both servers")
    }),
    it("passes other signals on at once", fn() {
      // Arrange
      let port = free_port()
      let assert Ok(handle) = start(port, process.new_subject())
      let signals = process.new_subject()
      let manager = start_signal_manager(signals)
      drain_on_sigterm(manager, server_pid(handle))

      // Act
      notify(manager, atom.create("sigusr2"))
      let signal = process.receive(signals, 1000) |> result.map(atom.to_string)
      stop_signal_manager(manager)
      server.stop(handle)

      // Assert
      signal
      |> should()
      |> be_equal(Ok("sigusr2"))
      |> or_fail_with("A signal other than SIGTERM must go to the next handler")
    }),
  ])
}

/// What the controllers of the test server tell the test
type Event {
  /// A request reached its controller
  Started
  /// The server asked the connection of a `/slow` request to drain. The
  /// controller answers when the test sends `Nil` to `release`.
  Draining(release: Subject(Nil))
}

/// Tells the test that the request started, waits until the server drains
/// the connection, and then waits for the test to release the request.
fn slow(_request: Request, _context, events: Subject(Event)) -> Response {
  process.send(events, Started)
  let _drained = await_drain(timeout_ms)
  let release = process.new_subject()
  process.send(events, Draining(release))
  let _released = process.receive(release, timeout_ms)
  text_response(ok, "slow done")
}

/// Tells the test that the request started, then never answers: nothing
/// sends to the subject, so the server must cut the request.
fn endless(_request: Request, _context, events: Subject(Event)) -> Response {
  process.send(events, Started)
  let _never = process.receive(process.new_subject(), 10_000)
  text_response(ok, "never")
}

fn fast(_request: Request, _context, _events: Subject(Event)) -> Response {
  text_response(ok, "fast")
}

fn start(port: Int, events: Subject(Event)) {
  server.new()
  |> server.services(events)
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: fast, middleware: [])
    |> route(method: Get, path: "/slow", controller: slow, middleware: [])
    |> route(method: Get, path: "/endless", controller: endless, middleware: []),
  )
  |> server.bind("127.0.0.1")
  |> server.shutdown_timeout(timeout_ms)
  |> server.listen_with_handle(port)
}

/// True when a controller tells the test that its request started
fn await_started(events: Subject(Event)) -> Bool {
  case process.receive(events, timeout_ms) {
    Ok(Started) -> True
    Ok(Draining(_release)) | Error(Nil) -> False
  }
}

/// Waits until a `/slow` request sees the drain, runs `during` while the
/// request still runs, and then releases the request.
fn on_drain(events: Subject(Event), during: fn() -> a) -> Result(a, Nil) {
  case process.receive(events, timeout_ms) {
    Ok(Draining(release)) -> {
      let result = during()
      process.send(release, Nil)
      Ok(result)
    }
    Ok(Started) | Error(Nil) -> Error(Nil)
  }
}

// Sends `request` from a new process, as a client does. The subject gets the
// bytes of the response, or no bytes when the server closes the connection
fn request_in_background(port: Int, request: String) -> Subject(BitArray) {
  let response = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      response,
      request_bytes(port, bit_array.from_string(request), timeout_ms),
    )
  })
  response
}

fn stop_gracefully_in_background(
  handle: server.ServerHandle,
  within: Int,
) -> Subject(Nil) {
  let stopped = process.new_subject()
  process.spawn_unlinked(fn() {
    server.stop_gracefully(handle, within:)
    process.send(stopped, Nil)
  })
  stopped
}

// The status line, the connection header and the body of a response
fn describe_response(bytes: BitArray) -> #(String, String, String) {
  let text = result.unwrap(bit_array.to_string(bytes), "")
  let #(head, body) =
    result.unwrap(string.split_once(text, "\r\n\r\n"), #(text, ""))
  let lines = string.split(head, "\r\n")
  let status_line = result.unwrap(list.first(lines), "")
  let connection =
    lines
    |> list.find_map(fn(line) {
      case string.split_once(line, ": ") {
        Ok(#("connection", value)) -> Ok(value)
        _ -> Error(Nil)
      }
    })
    |> result.unwrap("")
  #(status_line, connection, body)
}

type Socket

type Manager

@external(erlang, "graceful_stop_ffi", "request")
fn request_bytes(port: Int, request: BitArray, timeout: Int) -> BitArray

@external(erlang, "graceful_stop_ffi", "open_idle")
fn open_idle(port: Int, request: String) -> Socket

@external(erlang, "graceful_stop_ffi", "closed_within")
fn closed_within(socket: Socket, timeout: Int) -> Bool

@external(erlang, "graceful_stop_ffi", "connect")
fn connect(port: Int) -> String

@external(erlang, "graceful_stop_ffi", "await_drain")
fn await_drain(timeout: Int) -> Bool

@external(erlang, "graceful_stop_ffi", "now_ms")
fn now_ms() -> Int

@external(erlang, "graceful_stop_ffi", "start_signal_manager")
fn start_signal_manager(signals: Subject(Atom)) -> Manager

@external(erlang, "graceful_stop_ffi", "stop_signal_manager")
fn stop_signal_manager(manager: Manager) -> Nil

@external(erlang, "graceful_stop_ffi", "notify")
fn notify(manager: Manager, signal: Atom) -> Nil

@external(erlang, "dream_mist_sigterm", "install")
fn install_on(manager: Manager, next: Atom, server: Pid) -> Nil

fn drain_on_sigterm(manager: Manager, server: Pid) -> Nil {
  install_on(manager, atom.create("graceful_stop_ffi"), server)
}

@external(erlang, "graceful_stop_ffi", "server_pid")
fn server_pid(handle: server.ServerHandle) -> Pid

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
