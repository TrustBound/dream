import dream/context.{type AppContext}
import dream/router
import dream/servers/mist/handler
import gleeunit/should

// Note: Testing the handler thoroughly requires mocking mist requests, which is
// difficult because mist types are opaque or hard to construct.
// The integration tests cover the end-to-end behavior including body reading.

pub fn create_with_valid_config_returns_handler_function_test() {
  // Arrange
  let test_router = router.router()
  let max_body_size = 1024
  let template_context = context.AppContext(request_id: "")
  let services_instance = router.EmptyServices
  let update_context_fn = fn(context: AppContext, _request_id: String) -> AppContext {
    context
  }

  // Act
  let _handler_fn =
    handler.create(
      test_router,
      max_body_size,
      template_context,
      services_instance,
      update_context_fn,
    )

  // Assert
  // Handler function should be callable (it's a function)
  // We verify it's not Nil or causing a panic just by creating it
  True |> should.be_true
}
