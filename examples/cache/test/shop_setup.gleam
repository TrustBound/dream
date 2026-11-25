//// Starts the services of the shop for a suite, with a fixed clock and a
//// catalog with no delay, and stops them after the suite.

import clock.{FixedClock}
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import services.{type Services, Settings}

/// The time of the first request of each test
pub fn start_time() -> Timestamp {
  timestamp.from_unix_seconds(1_800_000_000)
}

/// The services with tables of their own, named after `suite`, at
/// `start_time`
pub fn start_shop(suite: String) -> Result(Services, String) {
  services.start_services(Settings(
    table_prefix: "shop_test_" <> suite,
    catalog_delay_milliseconds: 0,
    time_to_live: duration.seconds(60),
    clock: FixedClock(start_time()),
  ))
}

pub fn stop_shop(services: Services) -> Result(Nil, String) {
  Ok(services.stop_services(services))
}

/// The same services, with the clock `seconds` after `start_time`
pub fn at_second(services: Services, seconds: Int) -> Services {
  let time = timestamp.add(start_time(), duration.seconds(seconds))
  services.Services(..services, clock: FixedClock(time))
}
