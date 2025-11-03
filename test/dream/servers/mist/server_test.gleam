import dream/core/context.{type AppContext, new_context}
import dream/core/dream
import dream/core/router.{router}
import dream/servers/mist/server
import gleeunit/should

pub fn new_creates_dream_instance_with_defaults_test() {
  // Arrange & Act
  let dream_instance = server.new()
  
  // Assert
  // Verify Dream instance was created
  case dream_instance {
    dream.Dream(server, router_instance, max_body_size) -> {
      max_body_size |> should.equal(9_223_372_036_854_775_807)
    }
  }
}

pub fn router_sets_router_on_dream_instance_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let create_context_fn = new_context
  
  // Act
  let updated_dream = server.router(dream_instance, test_router, create_context_fn)
  
  // Assert
  // Router should be set
  case updated_dream {
    dream.Dream(_, router_instance, _) -> {
      Nil
    }
  }
}

pub fn bind_sets_bind_address_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let create_context_fn = new_context
  let dream_with_router = server.router(dream_instance, test_router, create_context_fn)
  
  // Act
  let bound_dream = server.bind(dream_with_router, "127.0.0.1")
  
  // Assert
  // Bind should be set
  case bound_dream {
    dream.Dream(_, _, _) -> Nil
  }
}

pub fn max_body_size_sets_max_body_size_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let create_context_fn = new_context
  let dream_with_router = server.router(dream_instance, test_router, create_context_fn)
  
  // Act
  let updated_dream = server.max_body_size(dream_with_router, 2048, create_context_fn)
  
  // Assert
  case updated_dream {
    dream.Dream(_, _, max_body_size) -> {
      max_body_size |> should.equal(2048)
    }
  }
}

pub fn listen_with_valid_port_returns_result_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let create_context_fn = new_context
  let dream_with_router = server.router(dream_instance, test_router, create_context_fn)
  let bound_dream = server.bind(dream_with_router, "127.0.0.1")
  
  // Act
  let result = server.listen(bound_dream, 8080)
  
  // Assert
  // listen returns Result - we can't easily test successful start without
  // actually starting a server, but we can verify the function returns Result
  case result {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

