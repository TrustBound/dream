//// Router performance benchmarks.
////
//// These benchmarks measure radix trie lookup performance with process isolation.

import dream/context
import dream/http/request.{Get}
import dream/router
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{test_handler}
import fixtures/request as test_request
import gleam/int
import gleam/io

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("router benchmarks", [
    describe("100 routes", [
      it("first route lookup", fn() {
        let router = generate_routes(100)
        let elapsed = time_router_lookup(router, "/api/v0/resource0", 10_000)
        print_result("100-first", elapsed, 10_000)
        AssertionOk
      }),
      it("middle route lookup", fn() {
        let router = generate_routes(100)
        let elapsed = time_router_lookup(router, "/api/v2/resource50", 10_000)
        print_result("100-middle", elapsed, 10_000)
        AssertionOk
      }),
      it("last route lookup", fn() {
        let router = generate_routes(100)
        let elapsed = time_router_lookup(router, "/api/v4/resource99", 10_000)
        print_result("100-last", elapsed, 10_000)
        AssertionOk
      }),
    ]),
    describe("large route tables", [
      it("500 routes last route", fn() {
        let router = generate_routes(500)
        let elapsed = time_router_lookup(router, "/api/v24/resource499", 5000)
        print_result("500-last", elapsed, 5000)
        AssertionOk
      }),
      it("1000 routes last route", fn() {
        let router = generate_routes(1000)
        let elapsed = time_router_lookup(router, "/api/v49/resource999", 1000)
        print_result("1000-last", elapsed, 1000)
        AssertionOk
      }),
    ]),
    describe("not found", [
      it("fails fast on first segment", fn() {
        let router = generate_routes(500)
        let elapsed = time_router_lookup(router, "/nonexistent/path", 10_000)
        print_result("500-notfound", elapsed, 10_000)
        AssertionOk
      }),
    ]),
  ])
}

// ============================================================================
// Route Generation
// ============================================================================

fn generate_routes(
  count: Int,
) -> router.Router(context.AppContext, router.EmptyServices) {
  do_generate_routes(router.router(), 0, count)
}

fn do_generate_routes(
  current_router: router.Router(context.AppContext, router.EmptyServices),
  current: Int,
  total: Int,
) -> router.Router(context.AppContext, router.EmptyServices) {
  case current >= total {
    True -> current_router
    False -> {
      let path =
        "/api/v"
        <> int.to_string(current / 20)
        <> "/resource"
        <> int.to_string(current)
      let updated =
        router.route(
          current_router,
          method: Get,
          path: path,
          controller: test_handler,
          middleware: [],
        )
      do_generate_routes(updated, current + 1, total)
    }
  }
}

// ============================================================================
// Timing Functions
// ============================================================================

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: Int) -> Int

fn microsecond_unit() -> Int {
  1_000_000
}

fn time_router_lookup(
  router_instance: router.Router(context.AppContext, router.EmptyServices),
  path: String,
  iterations: Int,
) -> Int {
  let request = test_request.create_request(Get, path)
  let start = monotonic_time(microsecond_unit())
  do_router_iterations(router_instance, request, iterations)
  let end = monotonic_time(microsecond_unit())
  end - start
}

fn do_router_iterations(
  router_instance: router.Router(context.AppContext, router.EmptyServices),
  request: request.Request,
  iterations: Int,
) -> Nil {
  case iterations {
    0 -> Nil
    _ -> {
      let _ = router.find_route(router_instance, request)
      do_router_iterations(router_instance, request, iterations - 1)
    }
  }
}

// ============================================================================
// Output Helpers
// ============================================================================

fn print_result(name: String, elapsed: Int, iterations: Int) -> Nil {
  let average = int.to_float(elapsed) /. int.to_float(iterations)
  io.println(
    "[BENCH] "
    <> name
    <> ": "
    <> int.to_string(elapsed)
    <> "μs total, "
    <> format_float(average)
    <> "μs/lookup ("
    <> int.to_string(iterations)
    <> " iterations)",
  )
}

fn format_float(value: Float) -> String {
  let truncated = float_truncate(value)
  let decimal_part =
    float_truncate({ value -. int.to_float(truncated) } *. 100.0)
  int.to_string(truncated) <> "." <> int.to_string(decimal_part)
}

@external(erlang, "erlang", "trunc")
fn float_truncate(value: Float) -> Int
