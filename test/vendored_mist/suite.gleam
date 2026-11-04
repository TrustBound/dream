//// Registers the vendored mist test suites with dream's test runner.
////
//// The test bodies under test/vendored_mist/ are copied from the TrustBound
//// mist fork unchanged. They are plain `*_test` functions that use `assert`,
//// so each one is wrapped here as a dream_test unit test. A failing `assert`
//// panics, which the isolated runner reports as a failed test.
////
//// Run these suites with `max_concurrency: 1`: the HTTP/1 tests all listen
//// on port 8888, as they did under gleeunit, which ran them one at a time.
////
//// Each HTTP/1 test starts a server on port 8888, sends one hackney request
//// and kills the server. hackney keeps the connection in its default pool
//// with keep-alive. If the next test checks that socket out before the pool
//// has seen the server close it, the request fails with `Error(Closed)`.
//// The fork's gleeunit run only avoided this race by timing. `run_http1`
//// stops the pool before each HTTP/1 test so every test opens a new
//// connection.

import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/erlang/atom.{type Atom}
import vendored_mist/http1_test
import vendored_mist/http2_test
import vendored_mist/mist/http2/flow_control_test
import vendored_mist/mist/http2/frame_test

pub type Suite {
  Suite(name: String, tests: UnitTest)
}

/// One dream_test suite per vendored mist test module.
pub fn suites() -> List(Suite) {
  [
    Suite(
      "vendored_mist/http1",
      describe("vendored_mist/http1", [
        it("it echoes with data", fn() {
          run_http1(http1_test.it_echoes_with_data_test)
        }),
        it("it supports large header fields", fn() {
          run_http1(http1_test.it_supports_large_header_fields_test)
        }),
        it("it supports patch requests", fn() {
          run_http1(http1_test.it_supports_patch_requests_test)
        }),
        it("it rejects large requests", fn() {
          run_http1(http1_test.it_rejects_large_requests_test)
        }),
        it("it supports chunked encoding", fn() {
          run_http1(http1_test.it_supports_chunked_encoding_test)
        }),
        it("it supports query parameters", fn() {
          run_http1(http1_test.it_supports_query_parameters_test)
        }),
        it("it handles query parameters with question mark", fn() {
          run_http1(
            http1_test.it_handles_query_parameters_with_question_mark_test,
          )
        }),
        it("it doesnt mangle query", fn() {
          run_http1(http1_test.it_doesnt_mangle_query_test)
        }),
        it("it supports expect continue header", fn() {
          run_http1(http1_test.it_supports_expect_continue_header_test)
        }),
        it("it sends back chunked responses", fn() {
          run_http1(http1_test.it_sends_back_chunked_responses_test)
        }),
      ]),
    ),
    Suite(
      "vendored_mist/http2",
      describe("vendored_mist/http2", [
        it("it responds to ping with ack", fn() {
          run(http2_test.it_responds_to_ping_with_ack_test)
        }),
        it("it sends settings ack", fn() {
          run(http2_test.it_sends_settings_ack_test)
        }),
        it("it handles basic get request", fn() {
          run(http2_test.it_handles_basic_get_request_test)
        }),
        it("it handles rst stream", fn() {
          run(http2_test.it_handles_rst_stream_test)
        }),
        it("it sends goaway on protocol error", fn() {
          run(http2_test.it_sends_goaway_on_protocol_error_test)
        }),
        it("it keeps connection alive after request", fn() {
          run(http2_test.it_keeps_connection_alive_after_request_test)
        }),
        it("it handles multiple requests same connection", fn() {
          run(http2_test.it_handles_multiple_requests_same_connection_test)
        }),
        it("it ignores window update for closed stream", fn() {
          run(http2_test.it_ignores_window_update_for_closed_stream_test)
        }),
        it("it ignores unknown frame type", fn() {
          run(http2_test.it_ignores_unknown_frame_type_test)
        }),
        it("it sends continuation frames for large headers", fn() {
          run(http2_test.it_sends_continuation_frames_for_large_headers_test)
        }),
        it("it sends chunked data over h2", fn() {
          run(http2_test.it_sends_chunked_data_over_h2_test)
        }),
        it("it handles sse over h2c", fn() {
          run(http2_test.it_handles_sse_over_h2c_test)
        }),
        it("it sse does not crash concurrent streams", fn() {
          run(http2_test.it_sse_does_not_crash_concurrent_streams_test)
        }),
        it("it closes sse stream on actor stop", fn() {
          run(http2_test.it_closes_sse_stream_on_actor_stop_test)
        }),
        it("it does not leak stream actors", fn() {
          run(http2_test.it_does_not_leak_stream_actors_test)
        }),
        it("it handles sse over h2c production path", fn() {
          run(http2_test.it_handles_sse_over_h2c_production_path_test)
        }),
        it("it handles sse under load production path", fn() {
          run(http2_test.it_handles_sse_under_load_production_path_test)
        }),
      ]),
    ),
    Suite(
      "vendored_mist/mist/http2/frame",
      describe("vendored_mist/mist/http2/frame", [
        it("it should encode data frame", fn() {
          run(frame_test.it_should_encode_data_frame_test)
        }),
        it("it should encode headers frame", fn() {
          run(frame_test.it_should_encode_headers_frame_test)
        }),
        it("it should encode data frame with end of stream", fn() {
          run(frame_test.it_should_encode_data_frame_with_end_of_stream_test)
        }),
        it("it should encode headers frame with end of stream", fn() {
          run(frame_test.it_should_encode_headers_frame_with_end_of_stream_test)
        }),
        it("it should return error when incomplete", fn() {
          run(frame_test.it_should_return_error_when_incomplete_test)
        }),
        it("it should decode data frame", fn() {
          run(frame_test.it_should_decode_data_frame_test)
        }),
        it("it should decode full header message", fn() {
          run(frame_test.it_should_decode_full_header_message_test)
        }),
        it("it should encode ping", fn() {
          run(frame_test.it_should_encode_ping_test)
        }),
        it("it should encode ping ack", fn() {
          run(frame_test.it_should_encode_ping_ack_test)
        }),
        it("it should decode ping", fn() {
          run(frame_test.it_should_decode_ping_test)
        }),
        it("it should decode ping ack", fn() {
          run(frame_test.it_should_decode_ping_ack_test)
        }),
        it("it should reject ping with wrong length", fn() {
          run(frame_test.it_should_reject_ping_with_wrong_length_test)
        }),
        it("it should encode termination", fn() {
          run(frame_test.it_should_encode_termination_test)
        }),
        it("it should decode termination", fn() {
          run(frame_test.it_should_decode_termination_test)
        }),
        it("it should encode goaway", fn() {
          run(frame_test.it_should_encode_goaway_test)
        }),
        it("it should decode goaway", fn() {
          run(frame_test.it_should_decode_goaway_test)
        }),
        it("it should encode goaway with debug data", fn() {
          run(frame_test.it_should_encode_goaway_with_debug_data_test)
        }),
        it("it should decode goaway with debug data", fn() {
          run(frame_test.it_should_decode_goaway_with_debug_data_test)
        }),
        it("it should encode window update", fn() {
          run(frame_test.it_should_encode_window_update_test)
        }),
        it("it should decode window update", fn() {
          run(frame_test.it_should_decode_window_update_test)
        }),
        it("it should reject window update with zero increment", fn() {
          run(
            frame_test.it_should_reject_window_update_with_zero_increment_test,
          )
        }),
        it("it should encode settings", fn() {
          run(frame_test.it_should_encode_settings_test)
        }),
        it("it should decode settings", fn() {
          run(frame_test.it_should_decode_settings_test)
        }),
        it("it should encode settings ack", fn() {
          run(frame_test.it_should_encode_settings_ack_test)
        }),
        it("it should decode settings ack", fn() {
          run(frame_test.it_should_decode_settings_ack_test)
        }),
        it("it should reject settings with wrong length", fn() {
          run(frame_test.it_should_reject_settings_with_wrong_length_test)
        }),
        it("it should encode priority", fn() {
          run(frame_test.it_should_encode_priority_test)
        }),
        it("it should decode priority", fn() {
          run(frame_test.it_should_decode_priority_test)
        }),
        it("it should roundtrip ping", fn() {
          run(frame_test.it_should_roundtrip_ping_test)
        }),
        it("it should roundtrip goaway", fn() {
          run(frame_test.it_should_roundtrip_goaway_test)
        }),
        it("it should roundtrip goaway with debug data", fn() {
          run(frame_test.it_should_roundtrip_goaway_with_debug_data_test)
        }),
        it("it should roundtrip termination", fn() {
          run(frame_test.it_should_roundtrip_termination_test)
        }),
        it("it should roundtrip window update", fn() {
          run(frame_test.it_should_roundtrip_window_update_test)
        }),
        it("it should roundtrip settings", fn() {
          run(frame_test.it_should_roundtrip_settings_test)
        }),
        it("it should roundtrip priority", fn() {
          run(frame_test.it_should_roundtrip_priority_test)
        }),
        it("it should roundtrip data frame", fn() {
          run(frame_test.it_should_roundtrip_data_frame_test)
        }),
        it("it should roundtrip headers frame", fn() {
          run(frame_test.it_should_roundtrip_headers_frame_test)
        }),
        it("it should decode unknown frame type", fn() {
          run(frame_test.it_should_decode_unknown_frame_type_test)
        }),
      ]),
    ),
    Suite(
      "vendored_mist/mist/http2/flow_control",
      describe("vendored_mist/mist/http2/flow_control", [
        it("it should not increment window above threshold", fn() {
          run(
            flow_control_test.it_should_not_increment_window_above_threshold_test,
          )
        }),
        it("it should increment window below threshold", fn() {
          run(flow_control_test.it_should_increment_window_below_threshold_test)
        }),
        it("it should update send window", fn() {
          run(flow_control_test.it_should_update_send_window_test)
        }),
        it("it should reject send window overflow", fn() {
          run(flow_control_test.it_should_reject_send_window_overflow_test)
        }),
      ]),
    ),
  ]
}

fn run(test_fn: fn() -> a) -> AssertionResult {
  test_fn()
  AssertionOk
}

fn run_http1(test_fn: fn() -> a) -> AssertionResult {
  stop_hackney_pool(atom.create("default"))
  run(test_fn)
}

/// Stops hackney's connection pool, closing its pooled sockets. hackney
/// starts the pool again on the next request.
@external(erlang, "hackney_pool", "stop_pool")
fn stop_hackney_pool(name: Atom) -> b
