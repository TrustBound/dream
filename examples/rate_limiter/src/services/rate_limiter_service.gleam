//// A fixed-window rate limit for each client, in two dream_ets tables.
//// The first request of a client starts its windows, and each window lasts
//// `window_seconds`. Each request adds one to the count of its window in
//// one atomic ETS step.

import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}

pub type RateLimitConfig {
  RateLimitConfig(max_requests: Int, window_seconds: Int)
}

/// What the rate limit says about one request
pub type Decision {
  /// The request can go on. `remaining` more requests fit in the window.
  Allowed(limit: Int, remaining: Int)
  /// The client sent too many requests. The window ends in
  /// `retry_after_seconds`.
  Denied(limit: Int, retry_after_seconds: Int)
}

pub type RateLimitError {
  /// An ETS operation failed, for example because the table is gone
  StoreFailed(reason: String)
}

pub opaque type RateLimiter {
  RateLimiter(
    /// The time of the first request of each client, in milliseconds
    starts: Table(String, Int),
    /// The count of each window, under "<window start> <client>"
    counts: Table(String, Int),
    config: RateLimitConfig,
  )
}

/// 10 requests in each 60 seconds
pub fn default_config() -> RateLimitConfig {
  RateLimitConfig(max_requests: 10, window_seconds: 60)
}

/// Makes the two tables. The process that calls this function owns them:
/// call it in a process that lives as long as the app.
pub fn new(
  name: String,
  config: RateLimitConfig,
) -> Result(RateLimiter, EtsError) {
  use starts <- result.try(
    config.new(name <> "_starts")
    |> config.counter()
    |> config.write_concurrency(True)
    |> config.create(),
  )
  use counts <- result.map(
    config.new(name <> "_counts")
    |> config.counter()
    |> config.write_concurrency(True)
    |> config.create(),
  )
  RateLimiter(starts:, counts:, config:)
}

/// Counts one request of `client` at `now`, and says if it can go on
pub fn count_request(
  limiter: RateLimiter,
  client: String,
  now: Timestamp,
) -> Result(Decision, RateLimitError) {
  let now_milliseconds = to_milliseconds(now)
  use first_start <- result.try(find_first_start(
    limiter,
    client,
    now_milliseconds,
  ))
  let window_start = find_window_start(limiter, first_start, now_milliseconds)
  use count <- result.map(
    helpers.increment(limiter.counts, count_key(window_start, client))
    |> result.map_error(store_failed),
  )
  decide(limiter, count, window_start, now_milliseconds)
}

/// The time of the first request of `client`. `insert_new` is atomic: when
/// two first requests come at the same time, one start wins, and both use
/// it.
fn find_first_start(
  limiter: RateLimiter,
  client: String,
  now_milliseconds: Int,
) -> Result(Int, RateLimitError) {
  case operations.insert_new(limiter.starts, client, now_milliseconds) {
    Ok(True) -> Ok(now_milliseconds)
    Ok(False) -> read_first_start(limiter, client, now_milliseconds)
    Error(error) -> Error(store_failed(error))
  }
}

fn read_first_start(
  limiter: RateLimiter,
  client: String,
  now_milliseconds: Int,
) -> Result(Int, RateLimitError) {
  case operations.get(limiter.starts, client) {
    Ok(Some(first_start)) -> Ok(first_start)
    // The sweep deleted the row after `insert_new` saw it: start again
    Ok(None) -> find_first_start(limiter, client, now_milliseconds)
    Error(error) -> Error(store_failed(error))
  }
}

/// The start of the window that holds `now`. The windows of a client follow
/// each other from its first request.
fn find_window_start(
  limiter: RateLimiter,
  first_start: Int,
  now_milliseconds: Int,
) -> Int {
  let window = window_milliseconds(limiter)
  first_start + { now_milliseconds - first_start } / window * window
}

fn decide(
  limiter: RateLimiter,
  count: Int,
  window_start: Int,
  now_milliseconds: Int,
) -> Decision {
  let limit = limiter.config.max_requests
  case count <= limit {
    True -> Allowed(limit:, remaining: limit - count)
    False -> {
      let left = window_start + window_milliseconds(limiter) - now_milliseconds
      Denied(limit:, retry_after_seconds: { left + 999 } / 1000)
    }
  }
}

/// Deletes the counts of the windows that ended before `now`, and the start
/// of each client with no request in its current window. Gives the number
/// of rows that it deleted. Without it, the tables keep rows for each
/// client that ever sent a request.
pub fn sweep(
  limiter: RateLimiter,
  now: Timestamp,
) -> Result(Int, RateLimitError) {
  let now_milliseconds = to_milliseconds(now)
  use counts <- result.try(sweep_counts(limiter, now_milliseconds))
  use starts <- result.map(sweep_starts(limiter, now_milliseconds))
  counts + starts
}

fn sweep_counts(
  limiter: RateLimiter,
  now_milliseconds: Int,
) -> Result(Int, RateLimitError) {
  use keys <- result.try(
    operations.keys(limiter.counts) |> result.map_error(store_failed),
  )
  let ended =
    list.filter(keys, fn(key) { has_ended(limiter, key, now_milliseconds) })
  delete_all(limiter.counts, ended)
}

fn sweep_starts(
  limiter: RateLimiter,
  now_milliseconds: Int,
) -> Result(Int, RateLimitError) {
  use starts <- result.try(
    operations.to_list(limiter.starts) |> result.map_error(store_failed),
  )
  let idle =
    starts
    |> list.filter(fn(row) { is_idle(limiter, row, now_milliseconds) })
    |> list.map(fn(row) { row.0 })
  delete_all(limiter.starts, idle)
}

/// A client is idle when its current window has no count
fn is_idle(
  limiter: RateLimiter,
  row: #(String, Int),
  now_milliseconds: Int,
) -> Bool {
  let #(client, first_start) = row
  let window_start = find_window_start(limiter, first_start, now_milliseconds)
  operations.member(limiter.counts, count_key(window_start, client))
  == Ok(False)
}

fn delete_all(
  table: Table(String, Int),
  keys: List(String),
) -> Result(Int, RateLimitError) {
  list.try_each(keys, fn(key) { operations.delete(table, key) })
  |> result.map_error(store_failed)
  |> result.replace(list.length(keys))
}

fn count_key(window_start: Int, client: String) -> String {
  int.to_string(window_start) <> " " <> client
}

/// True when the window at the front of a count key ended at `now`
fn has_ended(limiter: RateLimiter, key: String, now_milliseconds: Int) -> Bool {
  let window_start =
    string.split_once(key, " ")
    |> result.try(fn(parts) { int.parse(parts.0) })
  case window_start {
    Ok(start) -> start + window_milliseconds(limiter) <= now_milliseconds
    // Only `count_key` makes keys, so each key has a window start
    Error(Nil) -> False
  }
}

fn store_failed(error: EtsError) -> RateLimitError {
  StoreFailed(reason: string.inspect(error))
}

fn window_milliseconds(limiter: RateLimiter) -> Int {
  limiter.config.window_seconds * 1000
}

fn to_milliseconds(time: Timestamp) -> Int {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(time)
  seconds * 1000 + nanoseconds / 1_000_000
}
