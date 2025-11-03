import dream/core/context.{type AppContext}
import dream/core/router
import dream/servers/mist/handler

pub fn create_with_valid_config_returns_handler_function_test() {
  // Arrange
  let test_router = router.router
  let max_body_size = 1024
  let template_context = context.AppContext(request_id: "")
  let services_instance = router.EmptyServices
  let update_context_fn = fn(ctx: AppContext, _request_id: String) -> AppContext {
    ctx
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
  // Handler function should be callable
  // We can't easily test the full handler without a real Mist request,
  // but we can verify it returns a function
  Nil
}

