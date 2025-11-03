import dream/core/context
import gleeunit/should

pub fn new_context_with_request_id_returns_app_context_test() {
  // Arrange
  let request_id = "test-request-123"

  // Act
  let context = context.new_context(request_id)

  // Assert
  case context {
    context.AppContext(id) -> {
      id |> should.equal(request_id)
    }
  }
}

pub fn new_context_with_empty_string_returns_context_with_empty_id_test() {
  // Arrange
  let request_id = ""

  // Act
  let context = context.new_context(request_id)

  // Assert
  case context {
    context.AppContext(id) -> {
      id |> should.equal("")
    }
  }
}
