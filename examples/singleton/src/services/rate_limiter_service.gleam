//// Rate Limiter Service
////
//// A singleton-based service for tracking request rates per IP address.
//// Demonstrates using dream/core/singleton for global state management.

import dream_singleton
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/option
import gleam/time/timestamp
import gleam/int
import gleam/float

/// Message types for rate limiter singleton
pub type RateLimiterMessage {
  CheckAndIncrement(ip: String)
  Reset
}

/// Reply types from rate limiter
pub type RateLimiterReply {
  RateLimitStatus(allowed: Bool, remaining: Int, limit: Int)
  ResetComplete
}

/// Internal state tracking requests per IP
/// Maps IP address to (request_count, window_start_timestamp)
type RateLimiterState =
  Dict(String, #(Int, Int))

/// Configuration for rate limiting
pub type RateLimitConfig {
  RateLimitConfig(max_requests: Int, window_seconds: Int)
}

/// Default rate limit: 10 requests per 60 seconds
pub fn default_config() -> RateLimitConfig {
  RateLimitConfig(max_requests: 10, window_seconds: 60)
}

/// Start the rate limiter singleton service with a given name
pub fn start_with_name(
  name: process.Name(
    singleton.SingletonMessage(RateLimiterMessage, RateLimiterReply),
  ),
  config: RateLimitConfig,
) -> Result(process.Pid, String) {
  let initial_state = dict.new()
  singleton.start(name, #(initial_state, config), handle_message)
}

/// Handle messages to the rate limiter
fn handle_message(
  msg: RateLimiterMessage,
  state: #(RateLimiterState, RateLimitConfig),
) -> #(#(RateLimiterState, RateLimitConfig), option.Option(RateLimiterReply)) {
  let #(rate_state, config) = state

  case msg {
    CheckAndIncrement(ip) -> {
      let now = current_timestamp()
      let #(new_state, status) =
        check_and_increment_rate(rate_state, ip, now, config)
      #(#(new_state, config), option.Some(status))
    }
    Reset -> {
      #(#(dict.new(), config), option.Some(ResetComplete))
    }
  }
}

/// Check rate limit and increment counter if allowed
fn check_and_increment_rate(
  state: RateLimiterState,
  ip: String,
  now: Int,
  config: RateLimitConfig,
) -> #(RateLimiterState, RateLimiterReply) {
  case dict.get(state, ip) {
    Ok(#(count, window_start)) -> {
      // Check if we're still in the same time window
      let window_elapsed = now - window_start
      case window_elapsed < config.window_seconds {
        True -> {
          // Same window - check if under limit
          case count < config.max_requests {
            True -> {
              // Allow request and increment
              let new_state = dict.insert(state, ip, #(count + 1, window_start))
              let remaining = config.max_requests - count - 1
              #(
                new_state,
                RateLimitStatus(
                  allowed: True,
                  remaining: remaining,
                  limit: config.max_requests,
                ),
              )
            }
            False -> {
              // Rate limit exceeded
              #(
                state,
                RateLimitStatus(
                  allowed: False,
                  remaining: 0,
                  limit: config.max_requests,
                ),
              )
            }
          }
        }
        False -> {
          // New window - reset counter
          let new_state = dict.insert(state, ip, #(1, now))
          #(
            new_state,
            RateLimitStatus(
              allowed: True,
              remaining: config.max_requests - 1,
              limit: config.max_requests,
            ),
          )
        }
      }
    }
    Error(_) -> {
      // First request from this IP
      let new_state = dict.insert(state, ip, #(1, now))
      #(
        new_state,
        RateLimitStatus(
          allowed: True,
          remaining: config.max_requests - 1,
          limit: config.max_requests,
        ),
      )
    }
  }
}

/// Check rate limit for an IP address
pub fn check_and_increment(
  name: process.Name(
    singleton.SingletonMessage(RateLimiterMessage, RateLimiterReply),
  ),
  ip: String,
) -> Result(RateLimiterReply, String) {
  singleton.call(name, CheckAndIncrement(ip), 1000)
}

/// Reset all rate limits (useful for testing)
pub fn reset(
  name: process.Name(
    singleton.SingletonMessage(RateLimiterMessage, RateLimiterReply),
  ),
) -> Result(RateLimiterReply, String) {
  singleton.call(name, Reset, 1000)
}

/// Check if the service is running
pub fn is_running(
  name: process.Name(
    singleton.SingletonMessage(RateLimiterMessage, RateLimiterReply),
  ),
) -> Bool {
  singleton.is_running(name)
}

/// Get current timestamp in seconds (Unix epoch)
fn current_timestamp() -> Int {
  // Get current timestamp in seconds
  // Using system time for rate limiting
  let seconds_float = 
    timestamp.system_time()
    |> timestamp.to_unix_seconds()
  // Convert float to int using truncate (round down)
  float.truncate(seconds_float)
}

