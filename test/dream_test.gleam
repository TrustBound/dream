//// Main test entry point using dream_test framework.

import benchmarks/router_benchmark
import dream/context_test
import dream/dream_test as dream_module_test
import dream/http/cookie_test
import dream/http/error_test
import dream/http/header_test
import dream/http/params_test
import dream/http/request_test
import dream/http/response_test
import dream/http/status_test
import dream/http/validation_test
import dream/router/parser_test
import dream/router_test
import dream/servers/mist/chunked_stream_test
import dream/servers/mist/h2c_test
import dream/servers/mist/handler_test
import dream/servers/mist/request_test as mist_request_test
import dream/servers/mist/response_test as mist_response_test
import dream/servers/mist/server_test
import dream/servers/mist/sse_test
import dream/streaming_test
import dream_test/reporter/bdd
import dream_test/runner.{RunnerConfig}
import dream_test/unit
import gleam/io
import gleam/list
import gleam/option.{None}
import snippets_test
import vendored_mist/suite as vendored_mist

pub fn main() {
  let all_tests =
    [
      unit.to_test_cases("dream/context", context_test.tests()),
      unit.to_test_cases("dream/dream", dream_module_test.tests()),
      unit.to_test_cases("dream/http/cookie", cookie_test.tests()),
      unit.to_test_cases("dream/http/error", error_test.tests()),
      unit.to_test_cases("dream/http/header", header_test.tests()),
      unit.to_test_cases("dream/http/params", params_test.tests()),
      unit.to_test_cases("dream/http/request", request_test.tests()),
      unit.to_test_cases("dream/http/response", response_test.tests()),
      unit.to_test_cases("dream/http/status", status_test.tests()),
      unit.to_test_cases("dream/http/validation", validation_test.tests()),
      unit.to_test_cases("dream/router", router_test.tests()),
      unit.to_test_cases("dream/router/parser", parser_test.tests()),
      unit.to_test_cases(
        "dream/servers/mist/chunked_stream",
        chunked_stream_test.tests(),
      ),
      unit.to_test_cases("dream/servers/mist/h2c", h2c_test.tests()),
      unit.to_test_cases("dream/servers/mist/handler", handler_test.tests()),
      unit.to_test_cases(
        "dream/servers/mist/request",
        mist_request_test.tests(),
      ),
      unit.to_test_cases(
        "dream/servers/mist/response",
        mist_response_test.tests(),
      ),
      unit.to_test_cases("dream/servers/mist/server", server_test.tests()),
      unit.to_test_cases("dream/servers/mist/sse", sse_test.tests()),
      unit.to_test_cases("dream/streaming", streaming_test.tests()),
      unit.to_test_cases("benchmarks/router", router_benchmark.tests()),
      unit.to_test_cases("snippets", snippets_test.tests()),
    ]
    |> list.flatten

  let dream_results = runner.run_all(all_tests)

  // The vendored mist suites (test/vendored_mist/) came from gleeunit, which
  // ran them one at a time; several bind the same port. Run them one at a
  // time, with a longer timeout for the load tests.
  let vendored_mist_tests =
    vendored_mist.suites()
    |> list.map(fn(suite) { unit.to_test_cases(suite.name, suite.tests) })
    |> list.flatten

  let vendored_results =
    runner.run_all_with_config(
      RunnerConfig(
        max_concurrency: 1,
        default_timeout_ms: 60_000,
        test_filter: None,
      ),
      vendored_mist_tests,
    )

  list.append(dream_results, vendored_results)
  |> bdd.report(io.println)
  |> runner.exit_on_failure()
}
