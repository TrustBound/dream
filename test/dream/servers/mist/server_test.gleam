//// Tests for dream/servers/mist/server module.

import dream/dream
import dream/router.{router}
import dream/servers/mist/port_probe
import dream/servers/mist/server
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionFailed, AssertionFailure, AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("server", [
    builder_tests(),
    listen_tests(),
    lifecycle_tests(),
    bind_tests(),
  ])
}

fn builder_tests() -> UnitTest {
  describe("builder", [
    it("new creates dream instance with 10MB default max body size", fn() {
      // Arrange
      let dream_instance = server.new()

      // Act
      let result = dream.get_max_body_size(dream_instance)

      // Assert
      result
      |> should()
      |> equal(10_000_000)
      |> or_fail_with("Default max body size should be 10MB")
    }),
    it("router sets router on dream instance", fn() {
      // Arrange
      let dream_instance = server.new()
      let test_router = router()

      // Act
      let _configured = server.router(dream_instance, test_router)

      // Assert
      AssertionOk
    }),
    it("bind sets bind address", fn() {
      // Arrange
      let dream_instance = server.new()
      let test_router = router()
      let bind_address = "127.0.0.1"

      // Act
      let _configured =
        dream_instance
        |> server.router(test_router)
        |> server.bind(bind_address)

      // Assert
      AssertionOk
    }),
    it("max_body_size sets max body size", fn() {
      // Arrange
      let dream_instance = server.new()
      let test_router = router()
      let max_size = 2048

      // Act
      let _configured =
        dream_instance
        |> server.router(test_router)
        |> server.max_body_size(max_size)

      // Assert
      AssertionOk
    }),
  ])
}

fn listen_tests() -> UnitTest {
  describe("listen_with_handle", [
    it("starts on expected port", fn() {
      // Arrange
      let port = free_port()

      // Act
      let started = start_server_on(port)

      // Assert
      started
      |> result.map(fn(handle) {
        let in_use = port_probe.is_in_use(Some("127.0.0.1"), port)
        server.stop(handle)
        in_use
      })
      |> should()
      |> equal(Ok(True))
      |> or_fail_with(
        "The server should accept connections on the port it was given",
      )
    }),
  ])
}

fn lifecycle_tests() -> UnitTest {
  describe("server lifecycle", [
    it("listen_with_handle returns server handle", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          server.stop(handle)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "listen_with_handle",
            message: "Server failed to start on port "
              <> int.to_string(port)
              <> ": "
              <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    it("listen_with_handle fails when port is already in use", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
      let port = free_port()

      // Act
      let first_result = server.listen_with_handle(dream_instance, port)

      // Assert
      case first_result {
        Ok(handle) -> {
          let second_result = server.listen_with_handle(dream_instance, port)
          server.stop(handle)

          case second_result {
            Error(actor.InitFailed(message)) -> {
              case string.contains(message, "already in use") {
                True -> AssertionOk
                False ->
                  AssertionFailed(AssertionFailure(
                    operator: "listen_with_handle_port_in_use",
                    message: "Expected clear port-in-use message, got: "
                      <> message,
                    payload: None,
                  ))
              }
            }
            Error(start_error) ->
              AssertionFailed(AssertionFailure(
                operator: "listen_with_handle_port_in_use",
                message: "Unexpected start error: "
                  <> string.inspect(start_error),
                payload: None,
              ))
            Ok(_) ->
              AssertionFailed(AssertionFailure(
                operator: "listen_with_handle_port_in_use",
                message: "Expected second server start to fail on same port",
                payload: None,
              ))
          }
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "listen_with_handle_port_in_use",
            message: "Failed to start first server: "
              <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    it("stop actually stops server", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          process.sleep(100)
          server.stop(handle)
          process.sleep(100)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "stop",
            message: "Server failed to start: " <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    it("stop is idempotent", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          process.sleep(100)
          server.stop(handle)
          server.stop(handle)
          server.stop(handle)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "stop_idempotent",
            message: "Server failed to start: " <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    stop_from_another_process_tests(),
  ])
}

fn stop_from_another_process_tests() -> UnitTest {
  describe("stop from another process", [
    it("frees the port for a new server", fn() {
      // Arrange
      let port = free_port()
      let started = start_server_on(port)

      // Act
      let restarted =
        started
        |> result.try(stop_from_another_process(_, 1))
        |> result.try(fn(_stopped) { start_server_on(port) })

      // Assert
      restarted
      |> result.map(server.stop)
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("A new server must bind the port after stop returns")
    }),
    it("is safe to call twice", fn() {
      // Arrange
      let port = free_port()
      let started = start_server_on(port)

      // Act
      let restarted =
        started
        |> result.try(stop_from_another_process(_, 2))
        |> result.try(fn(_stopped) { start_server_on(port) })

      // Assert
      restarted
      |> result.map(server.stop)
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with(
        "Two stops must not crash the caller and must free the port",
      )
    }),
    it("is safe after the server already stopped", fn() {
      // Arrange
      let port = free_port()
      let stopped_by_owner =
        start_server_on(port)
        |> result.map(fn(handle) {
          server.stop(handle)
          handle
        })

      // Act
      let result =
        stopped_by_owner
        |> result.try(stop_from_another_process(_, 1))

      // Assert
      result
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("Stop on a stopped server must return Nil to the caller")
    }),
    it("refuses a connection sent after stop returns", fn() {
      // Arrange
      let port = free_port()
      let started = start_server_on(port)

      // Act
      let in_use =
        started
        |> result.try(stop_from_another_process(_, 1))
        |> result.map(fn(_stopped) {
          port_probe.is_in_use(Some("127.0.0.1"), port)
        })

      // Assert
      in_use
      |> should()
      |> equal(Ok(False))
      |> or_fail_with("The server must refuse connections after stop returns")
    }),
  ])
}

/// Starts a server on `port` in the calling process.
fn start_server_on(port: Int) -> Result(server.ServerHandle, String) {
  server.new()
  |> server.router(router())
  |> server.listen_with_handle(port)
  |> result.map_error(fn(start_error) {
    "Server failed to start: " <> string.inspect(start_error)
  })
}

/// Calls `server.stop` `times` times from a new process that is not linked
/// to the caller. Returns `Ok(Nil)` when that process reports that every call
/// returned, and an error when it does not report within 5 seconds (for
/// example because `stop` crashed it).
fn stop_from_another_process(
  handle: server.ServerHandle,
  times: Int,
) -> Result(Nil, String) {
  let reply = process.new_subject()
  process.spawn_unlinked(fn() {
    list.repeat(handle, times)
    |> list.each(server.stop)
    process.send(reply, Nil)
  })
  process.receive(reply, within: 5000)
  |> result.map_error(fn(_timeout) {
    "The stopping process did not report back within 5000 ms"
  })
}

@external(erlang, "doc_server_ffi", "free_port")
fn free_port() -> Int

fn bind_tests() -> UnitTest {
  describe("bind configuration", [
    it("bind configuration persists through listen", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
        |> server.bind("127.0.0.1")
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          server.stop(handle)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "bind_persists",
            message: "Server with bind() failed to start on port "
              <> int.to_string(port)
              <> ": "
              <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    it("bind to localhost works", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
        |> server.bind("localhost")
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          server.stop(handle)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "bind_localhost",
            message: "Server with bind('localhost') failed to start: "
              <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
    it("bind to all interfaces works", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
        |> server.bind("0.0.0.0")
      let port = free_port()

      // Act
      let result = server.listen_with_handle(dream_instance, port)

      // Assert
      case result {
        Ok(handle) -> {
          server.stop(handle)
          AssertionOk
        }
        Error(start_error) ->
          AssertionFailed(AssertionFailure(
            operator: "bind_all",
            message: "Server with bind('0.0.0.0') failed to start: "
              <> string.inspect(start_error),
            payload: None,
          ))
      }
    }),
  ])
}
