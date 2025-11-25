//// Rate Limiter Example
////
//// Demonstrates using dream_ets and ETS tables for global state management
//// with a practical rate limiting middleware implementation.
////
//// This example shows:
//// - Initializing an ETS-backed rate limiter service at application startup
//// - Accessing shared state from middleware
//// - Fixed window rate limiting (10 requests per 60 seconds)
//// - Rate limit headers in responses
////
//// To run:
////   cd examples/rate_limiter
////   make run
////
//// To test:
////   # Make a single request
////   curl -i http://localhost:3000/api
////
////   # Make multiple requests to trigger rate limiting
////   for i in {1..15}; do curl http://localhost:3000/api; echo ""; done

import dream/servers/mist/server.{bind, listen, router, services} as dream
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  dream.new()
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
