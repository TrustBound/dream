//// The rate limit of the guide "Add a cache and a rate limit": the limit,
//// the 429 with Retry-After, the new window, counts at the same time, and
//// the sweep.

import app_request.{describe_answer, get_from}
import clock.{FixedClock}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import services.{type Services}
import services/rate_limiter_service.{
  type Decision, type RateLimiter, Allowed, Denied,
}
import simplifile

pub fn tests() -> TestSuite {
  describe("Rate limit", context.setup(start_app, teardown: stop_app), [
    it(
      "allows 10 requests, answers 429 until the window ends",
      fn(services: Services) {
        let first_eleven =
          list.repeat(Nil, 11)
          |> list.map(fn(_) { get_api(services, 0, "203.0.113.7") })
        let later = [
          get_api(services, 30, "203.0.113.7"),
          get_api(services, 60, "203.0.113.7"),
        ]

        list.append(first_eleven, later)
        |> match_output("rate_limit")
      },
    ),
    it("counts each client on its own", fn(services: Services) {
      list.repeat(Nil, 11)
      |> list.each(fn(_) { get_api(services, 0, "198.51.100.1") })

      get_api(services, 0, "198.51.100.2")
      |> should
      |> be_equal("after 0 s: 200, remaining 9\n")
      |> or_fail_with("another client should have its own count")
    }),
    // These two tests make tables of their own: a sweep must not delete
    // the rows of the other tests
    it(
      "allows exactly 10 of 100 requests that arrive at the same time",
      fn(_services: Services) {
        use limiter <- result.try(new_limiter("rate_limit_concurrent"))

        let decisions = count_at_the_same_time(limiter, "192.0.2.50", 100)

        decisions
        |> list.count(is_allowed)
        |> should
        |> be_equal(10)
        |> or_fail_with("exactly 10 requests should get through")
      },
    ),
    it("sweeps the rows of windows that ended", fn(_services: Services) {
      use limiter <- result.try(new_limiter("rate_limit_sweep"))
      let counted =
        ["192.0.2.1", "192.0.2.2", "192.0.2.3"]
        |> list.try_each(fn(client) {
          rate_limiter_service.count_request(limiter, client, at(1000))
        })

      let before_the_end = rate_limiter_service.sweep(limiter, at(1059))
      let at_the_end = rate_limiter_service.sweep(limiter, at(1060))

      #(counted, before_the_end, at_the_end)
      |> should
      |> be_equal(#(Ok(Nil), Ok(0), Ok(6)))
      |> or_fail_with(
        "the sweep should delete 3 counts and 3 starts at second 60",
      )
    }),
    it(
      "answers the public page with no rate limit headers",
      fn(services: Services) {
        get_from(services, "/", "192.0.2.99")
        |> describe_answer(0, _)
        |> should
        |> be_equal("after 0 s: 200\n")
        |> or_fail_with("GET / should have no rate limit")
      },
    ),
  ])
}

fn start_app() -> Result(Services, String) {
  services.start_services(
    "rate_limit_test",
    rate_limiter_service.default_config(),
    FixedClock(start_time()),
  )
}

/// A rate limiter with tables of its own, owned by the test process
fn new_limiter(name: String) -> Result(RateLimiter, String) {
  rate_limiter_service.new(name, rate_limiter_service.default_config())
  |> result.map_error(string.inspect)
}

fn stop_app(services: Services) -> Result(Nil, String) {
  Ok(services.stop_services(services))
}

fn start_time() -> Timestamp {
  timestamp.from_unix_seconds(1_800_000_000)
}

/// The time `seconds` after the start, far from the other tests
fn at(seconds: Int) -> Timestamp {
  timestamp.add(start_time(), duration.seconds(seconds))
}

/// `GET /api` from `address`, `second` seconds after the start
fn get_api(services: Services, second: Int, address: String) -> String {
  services.Services(..services, clock: FixedClock(at(second)))
  |> get_from("/api", address)
  |> describe_answer(second, _)
}

/// Counts `total` requests of `client`, each in its own process, all at the
/// same time
fn count_at_the_same_time(
  limiter: RateLimiter,
  client: String,
  total: Int,
) -> List(Result(Decision, String)) {
  let answers = process.new_subject()
  list.repeat(Nil, total)
  |> list.each(fn(_) {
    process.spawn(fn() {
      rate_limiter_service.count_request(limiter, client, at(0))
      |> process.send(answers, _)
    })
  })
  list.repeat(Nil, total)
  |> list.map(fn(_) {
    process.receive(answers, within: 1000)
    |> result.replace_error("no answer in 1 second")
    |> result.try(result.map_error(_, string.inspect))
  })
}

fn is_allowed(decision: Result(Decision, String)) -> Bool {
  case decision {
    Ok(Allowed(..)) -> True
    Ok(Denied(..)) | Error(_) -> False
  }
}

/// Compares the answers with `test/outputs/<name>.txt`
fn match_output(
  answers: List(String),
  name: String,
) -> Result(AssertionResult, String) {
  use expected <- result.try(
    simplifile.read("test/outputs/" <> name <> ".txt")
    |> result.map_error(simplifile.describe_error),
  )
  string.concat(answers)
  |> should
  |> be_equal(expected)
  |> or_fail_with("the answers should match test/outputs/" <> name <> ".txt")
}
