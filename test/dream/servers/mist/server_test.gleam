//// Tests for dream/servers/mist/server module.

import dream/dream
import dream/router.{router}
import dream/servers/mist/server
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types.{AssertionFailed, AssertionFailure, AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}
import fixtures/hooks.{start_server, stop_server, test_server_port}
import gleam/erlang/process
import gleam/option.{None}
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
    before_each(start_server),
    after_each(stop_server),
    it("starts on expected port", fn() {
      // Arrange
      let expected_port = 19_999

      // Act
      let actual_port = test_server_port

      // Assert
      actual_port
      |> should()
      |> equal(expected_port)
      |> or_fail_with("Test server port should be 19999")
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
      let port = 19_990

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
            message: "Server failed to start on port 19990: "
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
      let port = 19_991

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
      let port = 19_992

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
  ])
}

fn bind_tests() -> UnitTest {
  describe("bind configuration", [
    it("bind configuration persists through listen", fn() {
      // Arrange
      let dream_instance =
        server.new()
        |> server.router(router())
        |> server.bind("127.0.0.1")
      let port = 19_993

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
            message: "Server with bind() failed to start on port 19993: "
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
      let port = 19_994

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
      let port = 19_995

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
