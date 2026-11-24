//// Main test entry point using dream_test framework.

import benchmarks/router_benchmark
import contributing_snippets_test
import doc_core_snippets_test
import doc_http_data_snippets_test
import doc_http_snippets_test
import doc_server_snippets_test
import docs_snippet_pages_test
import dream/context_test
import dream/controllers/static_test
import dream/dream_test as dream_module_test
import dream/http/cookie_test
import dream/http/error_test
import dream/http/header_test
import dream/http/params_test
import dream/http/request_test
import dream/http/response_test
import dream/http/status_test
import dream/http/transaction_test
import dream/http/validation_test
import dream/method_not_allowed_test
import dream/router/parser_test
import dream/router/trie_test
import dream/router_test
import dream/servers/mist/builder_order_test
import dream/servers/mist/chunked_stream_test
import dream/servers/mist/graceful_stop_test
import dream/servers/mist/h2c_test
import dream/servers/mist/handler_test
import dream/servers/mist/listen_test
import dream/servers/mist/request_body_test
import dream/servers/mist/request_test as mist_request_test
import dream/servers/mist/response_test as mist_response_test
import dream/servers/mist/server_test
import dream/servers/mist/sse_test
import dream/servers/mist/tls_test
import dream/servers/mist/unread_body_test
import dream/servers/mist/websocket_test
import dream/services/broadcaster_test
import dream/streaming_test
import dream_test/coverage
import dream_test/reporters/bdd
import dream_test/runner
import fixtures/port_ffi_test
import guide_reports_test
import guides_deployment_templates_snippets_test
import guides_sse_websockets_rest_snippets_test
import learning_snippets_test
import module_snippets_test
import naming_snippets_test
import reference_snippets_test
import security_snippets_test
import snippets/streaming_api_test
import snippets_test
import streaming_snippets_test
import testing_controllers_uploads_snippets_test
import websocket_chat_readme_snippets_test

pub fn main() {
  runner.new([
    context_test.tests(),
    dream_module_test.tests(),
    cookie_test.tests(),
    error_test.tests(),
    header_test.tests(),
    params_test.tests(),
    request_test.tests(),
    response_test.tests(),
    status_test.tests(),
    validation_test.tests(),
    transaction_test.tests(),
    static_test.tests(),
    router_test.tests(),
    method_not_allowed_test.tests(),
    parser_test.tests(),
    trie_test.tests(),
    builder_order_test.tests(),
    chunked_stream_test.tests(),
    h2c_test.tests(),
    handler_test.tests(),
    mist_request_test.tests(),
    request_body_test.tests(),
    mist_response_test.tests(),
    server_test.tests(),
    graceful_stop_test.tests(),
    listen_test.tests(),
    websocket_test.tests(),
    tls_test.tests(),
    unread_body_test.tests(),
    port_ffi_test.tests(),
    sse_test.tests(),
    broadcaster_test.tests(),
    streaming_test.tests(),
    router_benchmark.tests(),
    snippets_test.tests(),
    doc_http_snippets_test.tests(),
    doc_http_data_snippets_test.tests(),
    doc_server_snippets_test.tests(),
    doc_core_snippets_test.tests(),
    naming_snippets_test.tests(),
    reference_snippets_test.tests(),
    security_snippets_test.tests(),
    streaming_api_test.tests(),
    streaming_snippets_test.tests(),
    guides_sse_websockets_rest_snippets_test.tests(),
    testing_controllers_uploads_snippets_test.tests(),
    guides_deployment_templates_snippets_test.tests(),
    learning_snippets_test.tests(),
    module_snippets_test.tests(),
    contributing_snippets_test.tests(),
    websocket_chat_readme_snippets_test.tests(),
    docs_snippet_pages_test.tests(),
    guide_reports_test.tests(),
  ])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(
    coverage.new()
    |> coverage.show_missing()
    |> coverage.minimum_percent(100.0)
    |> coverage.json_path("build/coverage/coverage.json"),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
