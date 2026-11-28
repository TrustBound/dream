//// The cache of the guide "Add a cache and a rate limit": a miss, a hit,
//// expiry, and the removal of an entry after a write.

import app_request.{describe_exchange, send}
import dream/http/request.{Get, Put}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}
import gleam/result
import gleam/string
import services.{type Services}
import shop_setup.{at_second, start_shop, stop_shop}
import simplifile

pub fn tests() -> TestSuite {
  describe(
    "Product cache",
    context.setup(fn() { start_shop("cache") }, teardown: stop_shop),
    [
      it(
        "reads the catalog, then the cache, then the catalog after 60 s",
        fn(services: Services) {
          let first = get(services, 0, "/products/lamp")
          let second = get(services, 10, "/products/lamp")
          let third = get(services, 61, "/products/lamp")

          [first, second, third]
          |> match_output("cache_read_through")
        },
      ),
      it("reads the new price at once after a change", fn(services: Services) {
        let first = get(services, 0, "/products/mug")
        let change = put(services, 5, "/products/mug", "1500")
        let second = get(services, 6, "/products/mug")
        let third = get(services, 7, "/products/mug")

        [first, change, second, third]
        |> match_output("cache_invalidation")
      }),
      it(
        "answers 404 for a product that the catalog does not have",
        fn(services: Services) {
          let response = send(at_second(services, 0), Get, "/products/sofa", "")

          #(response.status, app_request.body_text(response))
          |> should
          |> be_equal(#(404, "No product sofa"))
          |> or_fail_with("GET /products/sofa should answer 404")
        },
      ),
      it("answers 400 for a price that is not a number", fn(services: Services) {
        let response =
          send(at_second(services, 0), Put, "/products/chair", "cheap")

        #(response.status, app_request.body_text(response))
        |> should
        |> be_equal(#(400, "The body must be a price in cents"))
        |> or_fail_with("PUT with a bad price should answer 400")
      }),
    ],
  )
}

fn get(services: Services, second: Int, path: String) -> String {
  send(at_second(services, second), Get, path, "")
  |> describe_exchange(second, "GET", path, _)
}

fn put(services: Services, second: Int, path: String, body: String) -> String {
  send(at_second(services, second), Put, path, body)
  |> describe_exchange(second, "PUT " <> body <> " to", path, _)
}

/// Compares the exchanges with `test/outputs/<name>.txt`
fn match_output(
  exchanges: List(String),
  name: String,
) -> Result(AssertionResult, String) {
  use expected <- result.try(
    simplifile.read("test/outputs/" <> name <> ".txt")
    |> result.map_error(simplifile.describe_error),
  )
  string.concat(exchanges)
  |> should
  |> be_equal(expected)
  |> or_fail_with("the exchanges should match test/outputs/" <> name <> ".txt")
}
