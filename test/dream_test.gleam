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
import dream/servers/mist/handler_test
import dream/servers/mist/request_test as mist_request_test
import dream/servers/mist/response_test as mist_response_test
import dream/servers/mist/server_test
import dream/streaming_test
import dream_test/reporter/bdd
import dream_test/runner
import dream_test/unit
import gleam/io
import gleam/list

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
      unit.to_test_cases("dream/streaming", streaming_test.tests()),
      unit.to_test_cases("benchmarks/router", router_benchmark.tests()),
    ]
    |> list.flatten

  all_tests
  |> runner.run_all()
  |> bdd.report(io.println)
  |> runner.exit_on_failure()
}
