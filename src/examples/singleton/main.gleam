//// Singleton Rate Limiter Example
////
//// Demonstrates using dream/core/singleton for global state management
//// with a practical rate limiting middleware implementation.
////
//// This example shows:
//// - Starting a singleton service at application startup
//// - Accessing the singleton from middleware
//// - Fixed window rate limiting (10 requests per 60 seconds)
//// - Rate limit headers in responses
////
//// To run:
////   gleam run -m examples/singleton
////
//// To test:
////   # Make a single request
////   curl -i http://localhost:3000/api
////
////   # Make multiple requests to trigger rate limiting
////   for i in {1..15}; do curl http://localhost:3000/api; echo ""; done

import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/singleton/router.{create_router}
import examples/singleton/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}

