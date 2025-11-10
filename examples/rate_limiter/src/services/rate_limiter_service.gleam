//// Rate Limiter Service
////
//// A simple rate limiter using ETS for tracking request counts per IP.
//// Demonstrates using dream_ets for stateful caching.

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/float
import gleam/option
import gleam/time/timestamp

/// Configuration for rate limiting
pub type RateLimitConfig {
  RateLimitConfig(max_requests: Int, window_seconds: Int)
}

/// Status of a rate limit check
pub type RateLimitStatus {
  RateLimitStatus(allowed: Bool, remaining: Int, limit: Int)
}

/// Rate limiter using ETS table
/// Uses counter for request counts
pub opaque type RateLimiter {
  RateLimiter(
    counts: table.Table(String, Int),
    windows: table.Table(String, Int),
    config: RateLimitConfig,
  )
}

/// Default rate limit: 10 requests per 60 seconds
pub fn default_config() -> RateLimitConfig {
  RateLimitConfig(max_requests: 10, window_seconds: 60)
}

/// Create a new rate limiter
pub fn new(
  name: String,
  config: RateLimitConfig,
) -> Result(RateLimiter, table.EtsError) {
  case create_counts_table(name), create_windows_table(name) {
    Ok(counts), Ok(windows) ->
      Ok(RateLimiter(counts: counts, windows: windows, config: config))
    Error(e), _ -> Error(e)
    _, Error(e) -> Error(e)
  }
}

fn create_counts_table(
  name: String,
) -> Result(table.Table(String, Int), table.EtsError) {
  config.new(name <> "_counts")
  |> config.counter()
  |> config.read_concurrency(True)
  |> config.write_concurrency(True)
  |> config.create()
}

fn create_windows_table(
  name: String,
) -> Result(table.Table(String, Int), table.EtsError) {
  config.new(name <> "_windows")
  |> config.counter()
  |> config.read_concurrency(True)
  |> config.write_concurrency(True)
  |> config.create()
}

/// Check rate limit and increment if allowed
pub fn check_and_increment(
  limiter: RateLimiter,
  ip: String,
) -> Result(RateLimitStatus, table.EtsError) {
  let RateLimiter(counts, windows, cfg) = limiter
  let now = current_timestamp()

  case get_window_start(windows, ip) {
    Ok(option.Some(window_start)) ->
      handle_existing_window(counts, windows, ip, window_start, now, cfg)
    Ok(option.None) -> initialize_new_window(counts, windows, ip, now, cfg)
    Error(err) -> Error(err)
  }
}

fn get_window_start(
  windows: table.Table(String, Int),
  ip: String,
) -> Result(option.Option(Int), table.EtsError) {
  operations.get(windows, ip)
}

fn handle_existing_window(
  counts: table.Table(String, Int),
  windows: table.Table(String, Int),
  ip: String,
  window_start: Int,
  now: Int,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  let window_elapsed = now - window_start

  case window_elapsed < cfg.window_seconds {
    True -> check_current_window(counts, ip, cfg)
    False -> reset_window(counts, windows, ip, now, cfg)
  }
}

fn check_current_window(
  counts: table.Table(String, Int),
  ip: String,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case operations.get(counts, ip) {
    Ok(option.Some(count)) -> handle_count_check(counts, ip, count, cfg)
    Ok(option.None) -> initialize_count(counts, ip, cfg)
    Error(err) -> Error(err)
  }
}

fn handle_count_check(
  counts: table.Table(String, Int),
  ip: String,
  count: Int,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case count < cfg.max_requests {
    True -> increment_and_allow(counts, ip, count, cfg)
    False -> deny_request(cfg)
  }
}

fn increment_and_allow(
  counts: table.Table(String, Int),
  ip: String,
  count: Int,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case operations.set(counts, ip, count + 1) {
    Ok(_) -> {
      let remaining = cfg.max_requests - count - 1
      Ok(RateLimitStatus(
        allowed: True,
        remaining: remaining,
        limit: cfg.max_requests,
      ))
    }
    Error(err) -> Error(err)
  }
}

fn initialize_count(
  counts: table.Table(String, Int),
  ip: String,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case operations.set(counts, ip, 1) {
    Ok(_) ->
      Ok(RateLimitStatus(
        allowed: True,
        remaining: cfg.max_requests - 1,
        limit: cfg.max_requests,
      ))
    Error(err) -> Error(err)
  }
}

fn deny_request(cfg: RateLimitConfig) -> Result(RateLimitStatus, table.EtsError) {
  Ok(RateLimitStatus(allowed: False, remaining: 0, limit: cfg.max_requests))
}

fn reset_window(
  counts: table.Table(String, Int),
  windows: table.Table(String, Int),
  ip: String,
  now: Int,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case operations.set(counts, ip, 1), operations.set(windows, ip, now) {
    Ok(_), Ok(_) ->
      Ok(RateLimitStatus(
        allowed: True,
        remaining: cfg.max_requests - 1,
        limit: cfg.max_requests,
      ))
    Error(e), _ -> Error(e)
    _, Error(e) -> Error(e)
  }
}

fn initialize_new_window(
  counts: table.Table(String, Int),
  windows: table.Table(String, Int),
  ip: String,
  now: Int,
  cfg: RateLimitConfig,
) -> Result(RateLimitStatus, table.EtsError) {
  case operations.set(counts, ip, 1), operations.set(windows, ip, now) {
    Ok(_), Ok(_) ->
      Ok(RateLimitStatus(
        allowed: True,
        remaining: cfg.max_requests - 1,
        limit: cfg.max_requests,
      ))
    Error(e), _ -> Error(e)
    _, Error(e) -> Error(e)
  }
}

/// Reset all rate limits
pub fn reset(limiter: RateLimiter) -> Result(Nil, table.EtsError) {
  let RateLimiter(counts, windows, _) = limiter
  case
    operations.delete_all_objects(counts),
    operations.delete_all_objects(windows)
  {
    Ok(_), Ok(_) -> Ok(Nil)
    Error(e), _ -> Error(e)
    _, Error(e) -> Error(e)
  }
}

/// Get current timestamp in seconds (Unix epoch)
fn current_timestamp() -> Int {
  let seconds_float =
    timestamp.system_time()
    |> timestamp.to_unix_seconds()
  float.truncate(seconds_float)
}
