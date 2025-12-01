//// Tests for dream/servers/mist/handler module.
////
//// Note: Testing the handler thoroughly requires mocking mist requests, which is
//// difficult because mist types are opaque or hard to construct.
//// The integration tests cover the end-to-end behavior including body reading.

import dream/context.{type AppContext}
import dream/router
import dream/servers/mist/handler
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("handler", [
    describe("create", [
      it("returns a handler function with valid config", fn() {
        let test_router = router.router()
        let max_body_size = 1024
        let template_context = context.AppContext(request_id: "")
        let services_instance = router.EmptyServices
        let update_context_function = fn(
          app_context: AppContext,
          _request_id: String,
        ) -> AppContext {
          app_context
        }

        // Handler function should be callable (it's a function)
        // We verify it's not Nil or causing a panic just by creating it
        let _ =
          handler.create(
            test_router,
            max_body_size,
            template_context,
            services_instance,
            update_context_function,
          )

        AssertionOk
      }),
    ]),
  ])
}
