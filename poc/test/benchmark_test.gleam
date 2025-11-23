// Real performance benchmark comparing radix trie vs linear search

import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleeunit/should
import router_poc

// Import Dream's types and router for direct comparison
import dream/context
import dream/http/request as dream_request
import dream/http/response as dream_response
import dream/router as dream_router

// ============================================================================
// Shared Controller (works with both routers since POC uses Dream types)
// ============================================================================

fn shared_controller(
  _request: dream_request.Request,
  _context: context.AppContext,
  _services: dream_router.EmptyServices,
) -> dream_response.Response {
  dream_response.Response(
    status: 200,
    body: dream_response.Text("OK"),
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
) -> router_poc.Router(context.AppContext, dream_router.EmptyServices) {
  let r = router_poc.router()
  do_generate_routes(r, 0, count)
}

fn do_generate_routes(
  r: router_poc.Router(context.AppContext, dream_router.EmptyServices),
  current: Int,
  total: Int,
) -> router_poc.Router(context.AppContext, dream_router.EmptyServices) {
  case current >= total {
    True -> r
    False -> {
      let path =
        "/api/v"
        <> int.to_string(current / 20)
        <> "/resource"
        <> int.to_string(current)
      let updated =
        router_poc.route(
          r,
          method: dream_request.Get,
          path: path,
          controller: shared_controller,
          middleware: [],
        )
      do_generate_routes(updated, current + 1, total)
    }
  }
}

fn generate_dream_router(
  count: Int,
) -> dream_router.Router(context.AppContext, dream_router.EmptyServices) {
  let r = dream_router.router
  do_generate_dream_routes(r, 0, count)
}

fn do_generate_dream_routes(
  r: dream_router.Router(context.AppContext, dream_router.EmptyServices),
  current: Int,
  total: Int,
) -> dream_router.Router(context.AppContext, dream_router.EmptyServices) {
  case current >= total {
    True -> r
    False -> {
      let path =
        "/api/v"
        <> int.to_string(current / 20)
        <> "/resource"
        <> int.to_string(current)
      let updated =
        dream_router.route(
          r,
          method: dream_request.Get,
          path: path,
          controller: shared_controller,
          middleware: [],
        )
      do_generate_dream_routes(updated, current + 1, total)
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

fn time_radix_lookup(
  router_instance: router_poc.Router(
    context.AppContext,
    dream_router.EmptyServices,
  ),
  path: String,
  iterations: Int,
) -> Int {
  let request =
    dream_request.Request(
      method: dream_request.Get,
      protocol: dream_request.Http,
      version: dream_request.Http1,
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
  do_radix_iterations(router_instance, request, iterations)
  let end = monotonic_time(microsecond_unit())
  end - start
}

fn do_radix_iterations(
  router_instance: router_poc.Router(
    context.AppContext,
    dream_router.EmptyServices,
  ),
  request: dream_request.Request,
  iterations: Int,
) -> Nil {
  case iterations {
    0 -> Nil
    _ -> {
      let _ = router_poc.find_route(router_instance, request)
      do_radix_iterations(router_instance, request, iterations - 1)
    }
  }
}

fn time_dream_lookup(
  dream_router_instance: dream_router.Router(
    context.AppContext,
    dream_router.EmptyServices,
  ),
  path: String,
  iterations: Int,
) -> Int {
  let request =
    dream_request.Request(
      method: dream_request.Get,
      protocol: dream_request.Http,
      version: dream_request.Http1,
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
  do_dream_iterations(dream_router_instance, request, iterations)
  let end = monotonic_time(microsecond_unit())
  end - start
}

fn do_dream_iterations(
  dream_router_instance: dream_router.Router(
    context.AppContext,
    dream_router.EmptyServices,
  ),
  request: dream_request.Request,
  iterations: Int,
) -> Nil {
  case iterations {
    0 -> Nil
    _ -> {
      let _ = dream_router.find_route(dream_router_instance, request)
      do_dream_iterations(dream_router_instance, request, iterations - 1)
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
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/api/v0/resource0"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")

  should.be_true(True)
}

pub fn benchmark_100_routes_middle_test() {
  let route_count = 100
  let iterations = 10_000

  io.println("\n=== Benchmark: 100 Routes, Middle Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/api/v2/resource50"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")

  should.be_true(True)
}

pub fn benchmark_100_routes_last_test() {
  let route_count = 100
  let iterations = 10_000

  io.println("\n=== Benchmark: 100 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/api/v4/resource99"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")

  should.be_true(True)
}

pub fn benchmark_500_routes_test() {
  let route_count = 500
  let iterations = 5000

  io.println("\n=== Benchmark: 500 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/api/v24/resource499"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")

  should.be_true(True)
}

pub fn benchmark_1000_routes_test() {
  let route_count = 1000
  let iterations = 1000

  io.println("\n=== Benchmark: 1000 Routes, Last Route ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/api/v49/resource999"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")

  should.be_true(True)
}

pub fn benchmark_not_found_test() {
  let route_count = 500
  let iterations = 10_000

  io.println("\n=== Benchmark: 500 Routes, Not Found ===")
  io.println("Iterations: " <> int.to_string(iterations))

  let radix_router = generate_routes(route_count)
  let dream_router_instance = generate_dream_router(route_count)

  let path = "/nonexistent/path"
  let radix_time = time_radix_lookup(radix_router, path, iterations)
  let dream_time = time_dream_lookup(dream_router_instance, path, iterations)

  let speedup = case radix_time {
    0 -> 0.0
    _ -> int.to_float(dream_time) /. int.to_float(radix_time)
  }

  io.println("Radix trie (POC):       " <> int.to_string(radix_time) <> " μs")
  io.println("Dream router (current): " <> int.to_string(dream_time) <> " μs")
  io.println("Speedup:                " <> float_to_string(speedup) <> "x")
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
