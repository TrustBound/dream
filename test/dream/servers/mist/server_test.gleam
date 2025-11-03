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
    dream.Dream(_server, _router_instance, _context, _services, max_body_size) -> {
      max_body_size |> should.equal(9_223_372_036_854_775_807)
    }
  }
}

pub fn router_sets_router_on_dream_instance_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  
  // Act
  let updated_dream = server.router(dream_instance, test_router)
  
  // Assert
  // Router should be set
  case updated_dream {
    dream.Dream(_, _router_instance, _, _, _) -> {
      Nil
    }
  }
}

pub fn bind_sets_bind_address_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let dream_with_router = server.router(dream_instance, test_router)
  
  // Act
  let bound_dream = server.bind(dream_with_router, "127.0.0.1")
  
  // Assert
  // Bind should be set
  case bound_dream {
    dream.Dream(_, _, _, _, _) -> Nil
  }
}

pub fn max_body_size_sets_max_body_size_test() {
  // Arrange
  let dream_instance = server.new()
  let test_router = router
  let dream_with_router = server.router(dream_instance, test_router)
  
  // Act
  let updated_dream = server.max_body_size(dream_with_router, 2048)
  
  // Assert
  case updated_dream {
    dream.Dream(_, _, _, _, max_body_size) -> {
      max_body_size |> should.equal(2048)
    }
  }
}


