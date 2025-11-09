//// Services
////
//// Application-level services for the singleton example.
//// Initializes and manages the rate limiter singleton.

import dream_singleton
import services/rate_limiter_service
import gleam/erlang/process
import gleam/io

/// Services type holding the rate limiter process name
pub type Services {
  Services(
    rate_limiter_name: process.Name(
      singleton.SingletonMessage(
        rate_limiter_service.RateLimiterMessage,
        rate_limiter_service.RateLimiterReply,
      ),
    ),
  )
}

/// Initialize application services
/// Starts the rate limiter singleton with default configuration
pub fn initialize_services() -> Services {
  // Create the process name once
  let name = process.new_name("rate_limiter_service")

  // Start the rate limiter singleton
  case
    rate_limiter_service.start_with_name(
      name,
      rate_limiter_service.default_config(),
    )
  {
    Ok(_pid) -> {
      io.println("✓ Rate limiter service started")
      Services(rate_limiter_name: name)
    }
    Error(msg) -> {
      // If already started (e.g., hot reload), that's fine
      case msg {
        "Singleton already started" -> {
          io.println("✓ Rate limiter service already running")
          Services(rate_limiter_name: name)
        }
        _ -> {
          io.println("✗ Failed to start rate limiter service: " <> msg)
          panic as "Could not initialize rate limiter service"
        }
      }
    }
  }
}
