//// Services
////
//// Application-level services for the rate limiter example.
//// Initializes and manages the rate limiter using dream_ets.

import dream_ets/table
import gleam/io
import services/rate_limiter_service

/// Services type holding the rate limiter
pub type Services {
  Services(rate_limiter: rate_limiter_service.RateLimiter)
}

/// Initialize application services
/// Creates the rate limiter ETS table with default configuration
pub fn initialize_services() -> Services {
  case create_rate_limiter() {
    Ok(limiter) -> Services(rate_limiter: limiter)
    Error(_) -> panic as "Could not initialize rate limiter service"
  }
}

fn create_rate_limiter() -> Result(
  rate_limiter_service.RateLimiter,
  table.EtsError,
) {
  case
    rate_limiter_service.new(
      "rate_limiter",
      rate_limiter_service.default_config(),
    )
  {
    Ok(limiter) -> {
      io.println("✓ Rate limiter service initialized")
      Ok(limiter)
    }
    Error(table.TableAlreadyExists) -> {
      io.println("✓ Rate limiter service already initialized")
      // Table exists from previous run - recreate the wrapper
      rate_limiter_service.new(
        "rate_limiter",
        rate_limiter_service.default_config(),
      )
    }
    Error(err) -> {
      io.println("✗ Failed to initialize rate limiter service")
      Error(err)
    }
  }
}
