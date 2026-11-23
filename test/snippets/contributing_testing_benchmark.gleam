//// A router benchmark. Shown in docs/contributing/testing.md.

import dream/context.{type AppContext}
import dream/http/request.{type Request, Get}
import dream/router.{type EmptyServices, type Router}
import dream_test/suite.{type TestSuite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import fixtures/handler.{test_handler}
import fixtures/request as test_request
import gleam/float
import gleam/int
import gleam/io

pub fn tests() -> TestSuite {
  describe("router benchmarks", [
    it("100 routes lookup", fn() {
      let resource_router = build_router(100)
      let request = test_request.create_request(Get, "/resources/99")
      let elapsed = time_lookups(resource_router, request, 10_000)

      io.println("[BENCH] 100-routes: " <> format_result(elapsed, 10_000))
      Ok(AssertionOk)
    }),
  ])
}

fn build_router(route_count: Int) -> Router(AppContext, EmptyServices) {
  add_resource_routes(router.router(), 0, route_count)
}

fn add_resource_routes(
  resource_router: Router(AppContext, EmptyServices),
  index: Int,
  route_count: Int,
) -> Router(AppContext, EmptyServices) {
  case index >= route_count {
    True -> resource_router
    False ->
      resource_router
      |> router.route(
        method: Get,
        path: "/resources/" <> int.to_string(index),
        controller: test_handler,
        middleware: [],
      )
      |> add_resource_routes(index + 1, route_count)
  }
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: Int) -> Int

const microseconds_per_second = 1_000_000

fn time_lookups(
  resource_router: Router(AppContext, EmptyServices),
  request: Request,
  iterations: Int,
) -> Int {
  let start = monotonic_time(microseconds_per_second)
  repeat_lookups(resource_router, request, iterations)
  monotonic_time(microseconds_per_second) - start
}

fn repeat_lookups(
  resource_router: Router(AppContext, EmptyServices),
  request: Request,
  iterations: Int,
) -> Nil {
  case iterations {
    0 -> Nil
    _ -> {
      let _ = router.find_route(resource_router, request)
      repeat_lookups(resource_router, request, iterations - 1)
    }
  }
}

fn format_result(elapsed: Int, iterations: Int) -> String {
  let per_lookup =
    float.to_precision(int.to_float(elapsed) /. int.to_float(iterations), 2)

  int.to_string(elapsed)
  <> "μs total, "
  <> float.to_string(per_lookup)
  <> "μs/lookup ("
  <> int.to_string(iterations)
  <> " iterations)"
}
