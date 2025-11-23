import dream/context
import dream/http/request
import dream/http/response
import dream/router
import gleam/int
import gleam/io
import gleam/option
import gleeunit/should

// ============================================================================
// Shared Controller (works with radix trie router)
// ============================================================================

fn shared_controller(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  response.Response(
    status: 200,
    body: response.Text("OK"),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

// ============================================================================
// Route Generation
// ============================================================================

fn generate_routes(
  count: Int,
) -> router.Router(context.AppContext, router.EmptyServices) {
  let r = router.router()
  do_generate_routes(r, 0, count)
}

fn do_generate_routes(
  r: router.Router(context.AppContext, router.EmptyServices),
  current: Int,
  total: Int,
) -> router.Router(context.AppContext, router.EmptyServices) {
  case current >= total {
    True -> r
    False -> {
      let path =
        "/api/v"
        <> int.to_string(current / 20)
        <> "/resource"
        <> int.to_string(current)
      let updated =
        router.route(
          r,
          method: request.Get,
          path: path,
          controller: shared_controller,
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
  let req =
    request.Request(
      method: request.Get,
      protocol: request.Http,
      version: request.Http1,
      path: path,
      query: "",
      params: [],
      host: option.None,
      port: option.None,
      remote_address: option.None,
      body: "",
      stream: option.None,
      headers: [],
      cookies: [],
      content_type: option.None,
      content_length: option.None,
    )
  let start = monotonic_time(microsecond_unit())
  do_router_iterations(router_instance, req, iterations)
  let end = monotonic_time(microsecond_unit())
  end - start
}

fn do_router_iterations(
  router_instance: router.Router(context.AppContext, router.EmptyServices),
  req: request.Request,
  iterations: Int,
) -> Nil {
  case iterations {
    0 -> Nil
    _ -> {
      let _ = router.find_route(router_instance, req)
      do_router_iterations(router_instance, req, iterations - 1)
    }
  }
}

// ============================================================================
// Benchmark Tests
// ============================================================================

pub fn benchmark_100_routes_first_test() {
  let route_count = 100
  let iterations = 10_000

  io.println("\n=== Benchmark: 100 Routes, First Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/api/v0/resource0"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )

  should.be_true(True)
}

pub fn benchmark_100_routes_middle_test() {
  let route_count = 100
  let iterations = 10_000

  io.println("\n=== Benchmark: 100 Routes, Middle Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/api/v2/resource50"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )

  should.be_true(True)
}

pub fn benchmark_100_routes_last_test() {
  let route_count = 100
  let iterations = 10_000

  io.println("\n=== Benchmark: 100 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/api/v4/resource99"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )

  should.be_true(True)
}

pub fn benchmark_500_routes_test() {
  let route_count = 500
  let iterations = 5000

  io.println("\n=== Benchmark: 500 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/api/v24/resource499"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )

  should.be_true(True)
}

pub fn benchmark_1000_routes_test() {
  let route_count = 1000
  let iterations = 1000

  io.println("\n=== Benchmark: 1000 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/api/v49/resource999"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )

  should.be_true(True)
}

pub fn benchmark_not_found_test() {
  let route_count = 500
  let iterations = 10_000

  io.println("\n=== Benchmark: 500 Routes, Not Found ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let path = "/nonexistent/path"
  let radix_time = time_router_lookup(radix_router, path, iterations)

  io.println("Radix trie router:      " <> int.to_string(radix_time) <> " μs")
  io.println(
    "Average per lookup:     "
    <> float_to_string(int.to_float(radix_time) /. int.to_float(iterations))
    <> " μs",
  )
  io.println("(Radix trie fails fast on first segment)")

  should.be_true(True)
}

// ============================================================================
// Helper Functions
// ============================================================================

fn float_to_string(f: Float) -> String {
  let truncated = float_truncate(f)
  let decimal_part = float_truncate({ f -. int.to_float(truncated) } *. 100.0)
  int.to_string(truncated) <> "." <> int.to_string(decimal_part)
}

@external(erlang, "erlang", "trunc")
fn float_truncate(f: Float) -> Int
