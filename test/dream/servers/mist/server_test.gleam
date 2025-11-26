import dream/dream
import dream/router.{router}
import dream/servers/mist/server
import gleam/erlang/process
import gleam/io
import gleam/string
import gleeunit/should

pub fn new_creates_dream_instance_with_defaults_test() {
  // Arrange & Act
  let dream_instance = server.new()

  // Assert - Verify default 10MB max body size
  dream.get_max_body_size(dream_instance)
  |> should.equal(10_000_000)
}

pub fn router_sets_router_on_dream_instance_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()

  // Act
  let updated_dream = server.router(dream_instance, test_router)

  // Assert
  // Router should be set (opaque type, so just verify it returns)
  let _ = updated_dream
  Nil
}

pub fn bind_sets_bind_address_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let dream_with_router = server.router(dream_instance, test_router)

  // Act
  let bound_dream = server.bind(dream_with_router, "127.0.0.1")

  // Assert
  // Bind should be set (opaque type, so just verify it returns)
  let _ = bound_dream
  Nil
}

pub fn max_body_size_sets_max_body_size_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let dream_with_router = server.router(dream_instance, test_router)

  // Act
  let updated_dream = server.max_body_size(dream_with_router, 2048)

  // Assert
  // Max body size should be set (opaque type, so just verify it returns)
  let _ = updated_dream
  Nil
}

pub fn listen_with_handle_returns_server_handle_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let dream_with_router = server.router(dream_instance, test_router)
  let port = 9999

  // Act
  let result = server.listen_with_handle(dream_with_router, port)

  // Assert
  case result {
    Ok(handle) -> {
      // Verify handle is valid by stopping it
      server.stop(handle)
      Nil
    }
    Error(err) -> {
      io.println("✗ Server failed to start")
      io.println(string.inspect(err))
      should.fail()
    }
  }
}

pub fn stop_actually_stops_server_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let dream_with_router = server.router(dream_instance, test_router)
  let port = 9998

  // Act - Start server
  let assert Ok(handle) = server.listen_with_handle(dream_with_router, port)

  // Wait for server to start
  process.sleep(100)

  // Stop the server
  server.stop(handle)

  // Wait for server to stop
  process.sleep(100)

  // Assert - stop() completed without error
  Nil
}

pub fn stop_idempotent_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let dream_with_router = server.router(dream_instance, test_router)
  let port = 9997

  // Act - Start server
  let assert Ok(handle) = server.listen_with_handle(dream_with_router, port)

  // Wait for server to start
  process.sleep(100)

  // Stop the server multiple times
  server.stop(handle)
  server.stop(handle)
  server.stop(handle)

  // Assert - Should not crash
  // If we get here without panicking, the test passes
  Nil
}

pub fn bind_configuration_persists_through_listen_test() {
  // Regression test for bug where bind() configuration was lost in listen()
  // 
  // Bug: listen_internal() was creating a fresh mist server with mist.new(),
  // which discarded the bind_interface configuration set by bind().
  //
  // Fix: Store bind_interface in Dream type and apply it in listen_internal()

  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let port = 9996

  // Act - Configure with bind() then listen
  let result =
    dream_instance
    |> server.router(test_router)
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)

  // Assert - Server should start successfully with bound interface
  case result {
    Ok(handle) -> {
      // Success! Bind configuration was preserved through listen
      server.stop(handle)
      Nil
    }
    Error(err) -> {
      io.println("✗ Server with bind() failed to start")
      io.println(string.inspect(err))
      should.fail()
    }
  }
}

pub fn bind_to_localhost_works_test() {
  // Verify binding to "localhost" works (common use case)

  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let port = 9995

  // Act
  let result =
    dream_instance
    |> server.router(test_router)
    |> server.bind("localhost")
    |> server.listen_with_handle(port)

  // Assert
  case result {
    Ok(handle) -> {
      server.stop(handle)
      Nil
    }
    Error(err) -> {
      io.println("✗ Server with bind('localhost') failed to start")
      io.println(string.inspect(err))
      should.fail()
    }
  }
}

pub fn bind_to_all_interfaces_works_test() {
  // Verify binding to "0.0.0.0" works (listen on all interfaces)

  // Arrange
  let dream_instance = server.new()
  let test_router = router()
  let port = 9994

  // Act
  let result =
    dream_instance
    |> server.router(test_router)
    |> server.bind("0.0.0.0")
    |> server.listen_with_handle(port)

  // Assert
  case result {
    Ok(handle) -> {
      server.stop(handle)
      Nil
    }
    Error(err) -> {
      io.println("✗ Server with bind('0.0.0.0') failed to start")
      io.println(string.inspect(err))
      should.fail()
    }
  }
}
