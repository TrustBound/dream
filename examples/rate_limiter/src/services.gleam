//// The services of the app: the rate limiter and the clock. One process
//// owns the tables of the rate limit, lives as long as the app, and deletes the
//// rows of ended windows once in each window.

import clock.{type Clock}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/result
import gleam/string
import services/rate_limiter_service.{type RateLimitConfig, type RateLimiter}

pub type Services {
  Services(
    rate_limiter: RateLimiter,
    clock: Clock,
    /// The process that owns the tables. Send it `Stop` to end it.
    table_owner: Subject(OwnerMessage),
  )
}

/// The messages of the process that owns the tables
pub type OwnerMessage {
  /// Delete the rows of ended windows
  Sweep
  /// End the process. The tables go away with it.
  Stop
}

/// Starts the process that owns the tables, and gives the services that
/// hold it.
pub fn start_services(
  table_name: String,
  config: RateLimitConfig,
  clock: Clock,
) -> Result(Services, String) {
  let reply = process.new_subject()
  process.spawn(fn() { own_tables(table_name, config, clock, reply) })
  process.receive(reply, within: 5000)
  |> result.replace_error("The table owner did not start in 5 seconds")
  |> result.flatten
}

/// Stops the process that owns the tables
pub fn stop_services(services: Services) -> Nil {
  process.send(services.table_owner, Stop)
}

/// Runs in the owner process: makes the tables, sends the services back,
/// then sweeps once in each window until it gets `Stop`
fn own_tables(
  table_name: String,
  config: RateLimitConfig,
  clock: Clock,
  reply: Subject(Result(Services, String)),
) -> Nil {
  let messages = process.new_subject()
  case rate_limiter_service.new(table_name, config) {
    Ok(limiter) -> {
      process.send(
        reply,
        Ok(Services(rate_limiter: limiter, clock:, table_owner: messages)),
      )
      wait_for_sweep(messages, limiter, clock, config.window_seconds * 1000)
    }
    Error(error) -> process.send(reply, Error(string.inspect(error)))
  }
}

fn wait_for_sweep(
  messages: Subject(OwnerMessage),
  limiter: RateLimiter,
  clock: Clock,
  interval_milliseconds: Int,
) -> Nil {
  process.send_after(messages, interval_milliseconds, Sweep)
  case process.receive_forever(messages) {
    Sweep -> sweep(messages, limiter, clock, interval_milliseconds)
    Stop -> Nil
  }
}

fn sweep(
  messages: Subject(OwnerMessage),
  limiter: RateLimiter,
  clock: Clock,
  interval_milliseconds: Int,
) -> Nil {
  case rate_limiter_service.sweep(limiter, clock.read_time(clock)) {
    Ok(_deleted) ->
      wait_for_sweep(messages, limiter, clock, interval_milliseconds)
    // This process owns the tables, so they cannot be gone here
    Error(rate_limiter_service.StoreFailed(reason:)) ->
      io.println_error("The sweep failed: " <> reason)
  }
}
