//// Router
////
//// Route definitions for the singleton example.
//// Demonstrates middleware application on specific routes.

import controllers/api_controller
import dream/context.{type AppContext}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import middleware/rate_limit_middleware
import services.{type Services}

/// Create router with rate-limited and public routes
pub fn create_router() -> Router(AppContext, Services) {
  router
  // Public route - no rate limiting
  |> route(
    method: Get,
    path: "/",
    controller: api_controller.welcome,
    middleware: [],
  )
  // Rate-limited API endpoint
  |> route(
    method: Get,
    path: "/api",
    controller: api_controller.index,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
  // Rate-limited status endpoint
  |> route(
    method: Get,
    path: "/api/status",
    controller: api_controller.status,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
}
