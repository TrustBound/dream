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
import vendored_glisten/glisten_test
import vendored_mist/http1_test
import vendored_mist/http2_test
import vendored_mist/mist/file_test
import vendored_mist/mist/http2/flow_control_test
import vendored_mist/mist/http2/frame_test

pub type Suite {
  Suite(name: String, tests: UnitTest)
}

/// One dream_test suite per vendored test module.
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
        it("it times out slow request bodies", fn() {
          run_http1(http1_test.it_times_out_slow_request_bodies_test)
        }),
      ]),
    ),
    Suite(
      "vendored_mist/http2",
      describe("vendored_mist/http2", [
        it("it applies pseudo headers", fn() {
          run(http2_test.it_applies_pseudo_headers_test)
        }),
        it("it rejects requests without host", fn() {
          run(http2_test.it_rejects_requests_without_host_test)
        }),
        it("it ignores unknown frames", fn() {
          run(http2_test.it_ignores_unknown_frames_test)
        }),
        it("it responds after reading the body", fn() {
          run(http2_test.it_responds_after_reading_the_body_test)
        }),
        it("it ignores window updates on closed streams", fn() {
          run(http2_test.it_ignores_window_updates_on_closed_streams_test)
        }),
        it("it handles frames sent with the preface", fn() {
          run(http2_test.it_handles_frames_sent_with_the_preface_test)
        }),
        it("it splits large bodies into frames", fn() {
          run(http2_test.it_splits_large_bodies_into_frames_test)
        }),
        it("it splits large headers into frames", fn() {
          run(http2_test.it_splits_large_headers_into_frames_test)
        }),
        it("it resets data on closed streams", fn() {
          run(http2_test.it_resets_data_on_closed_streams_test)
        }),
        it("it resets streams with invalid methods", fn() {
          run(http2_test.it_resets_streams_with_invalid_methods_test)
        }),
        it("it responds to ping", fn() {
          run(http2_test.it_responds_to_ping_test)
        }),
        it("it stops reset streams", fn() {
          run(http2_test.it_stops_reset_streams_test)
        }),
        it("it ignores unknown settings", fn() {
          run(http2_test.it_ignores_unknown_settings_test)
        }),
        it("it waits for window updates", fn() {
          run(http2_test.it_waits_for_window_updates_test)
        }),
        it("it sends go away on malformed frames", fn() {
          run(http2_test.it_sends_go_away_on_malformed_frames_test)
        }),
        it("it sends go away on malformed headers", fn() {
          run(http2_test.it_sends_go_away_on_malformed_headers_test)
        }),
        it("it sends server sent events", fn() {
          run(http2_test.it_sends_server_sent_events_test)
        }),
        it("it sends chunked responses", fn() {
          run(http2_test.it_sends_chunked_responses_test)
        }),
        it("it sends file responses", fn() {
          run(http2_test.it_sends_file_responses_test)
        }),
        it("it sends empty file responses", fn() {
          run(http2_test.it_sends_empty_file_responses_test)
        }),
        it("it responds with 500 on handler errors", fn() {
          run(http2_test.it_responds_with_500_on_handler_errors_test)
        }),
        it("it resets streams on handler errors after headers", fn() {
          run(http2_test.it_resets_streams_on_handler_errors_after_headers_test)
        }),
        it("it reads bodies without content length", fn() {
          run(http2_test.it_reads_bodies_without_content_length_test)
        }),
        it("it limits bodies without content length", fn() {
          run(http2_test.it_limits_bodies_without_content_length_test)
        }),
        it("it reads headers split into frames", fn() {
          run(http2_test.it_reads_headers_split_into_frames_test)
        }),
        it("it sends go away on frames inside headers", fn() {
          run(http2_test.it_sends_go_away_on_frames_inside_headers_test)
        }),
        it("it reads bodies ended by trailers", fn() {
          run(http2_test.it_reads_bodies_ended_by_trailers_test)
        }),
        it("it sends go away on oversized frames", fn() {
          run(http2_test.it_sends_go_away_on_oversized_frames_test)
        }),
        it("it waits for the window before sending more chunks", fn() {
          run(
            http2_test.it_waits_for_the_window_before_sending_more_chunks_test,
          )
        }),
        it("it fails sends on reset streams", fn() {
          run(http2_test.it_fails_sends_on_reset_streams_test)
        }),
        it("it stops the handler when a stream is reset", fn() {
          run(http2_test.it_stops_the_handler_when_a_stream_is_reset_test)
        }),
        it("it cancels sends that time out", fn() {
          run(http2_test.it_cancels_sends_that_time_out_test)
        }),
        it("it sends go away on reused stream ids", fn() {
          run(http2_test.it_sends_go_away_on_reused_stream_ids_test)
        }),
        it("it sends go away on continuation without headers", fn() {
          run(http2_test.it_sends_go_away_on_continuation_without_headers_test)
        }),
        it("it sends go away on oversized header blocks", fn() {
          run(http2_test.it_sends_go_away_on_oversized_header_blocks_test)
        }),
        it("it resets streams with wrong content length", fn() {
          run(http2_test.it_resets_streams_with_wrong_content_length_test)
        }),
        it("it resets trailers with wrong content length", fn() {
          run(http2_test.it_resets_trailers_with_wrong_content_length_test)
        }),
        it("it resets streams with content length and no body", fn() {
          run(http2_test.it_resets_streams_with_content_length_and_no_body_test)
        }),
        it("it keeps the connection after content length without a body", fn() {
          run(
            http2_test.it_keeps_the_connection_after_content_length_without_a_body_test,
          )
        }),
        it("it counts streams reset for content length without a body", fn() {
          run(
            http2_test.it_counts_streams_reset_for_content_length_without_a_body_test,
          )
        }),
        it("it resets data on half closed streams", fn() {
          run(http2_test.it_resets_data_on_half_closed_streams_test)
        }),
        it("it grants the stream window as the body is read", fn() {
          run(http2_test.it_grants_the_stream_window_as_the_body_is_read_test)
        }),
        it("it reads bodies larger than the stream window", fn() {
          run(http2_test.it_reads_bodies_larger_than_the_stream_window_test)
        }),
        it("it resets streams that exceed the receive window", fn() {
          run(http2_test.it_resets_streams_that_exceed_the_receive_window_test)
        }),
        it("it closes streams answered before the body ends", fn() {
          run(http2_test.it_closes_streams_answered_before_the_body_ends_test)
        }),
        it("it grants the stream window for padding", fn() {
          run(http2_test.it_grants_the_stream_window_for_padding_test)
        }),
        it("it counts padding against the receive window", fn() {
          run(http2_test.it_counts_padding_against_the_receive_window_test)
        }),
        it("it refuses streams over the concurrent stream limit", fn() {
          run(
            http2_test.it_refuses_streams_over_the_concurrent_stream_limit_test,
          )
        }),
        it("it waits for slow request bodies", fn() {
          run(http2_test.it_waits_for_slow_request_bodies_test)
        }),
        it("it times out sends after the send timeout", fn() {
          run(http2_test.it_times_out_sends_after_the_send_timeout_test)
        }),
        it("it times out slow request bodies", fn() {
          run(http2_test.it_times_out_slow_request_bodies_test)
        }),
        it("it advertises the initial window size", fn() {
          run(http2_test.it_advertises_the_initial_window_size_test)
        }),
        it("it receives bodies larger than the default window", fn() {
          run(http2_test.it_receives_bodies_larger_than_the_default_window_test)
        }),
        it("it advertises the configured initial window size", fn() {
          run(http2_test.it_advertises_the_configured_initial_window_size_test)
        }),
        it("it resets streams that exceed the configured window", fn() {
          run(
            http2_test.it_resets_streams_that_exceed_the_configured_window_test,
          )
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
        it("it should encode priority frame", fn() {
          run(frame_test.it_should_encode_priority_frame_test)
        }),
        it("it should encode ping frame", fn() {
          run(frame_test.it_should_encode_ping_frame_test)
        }),
        it("it should encode go away frame", fn() {
          run(frame_test.it_should_encode_go_away_frame_test)
        }),
        it("it should decode go away frame", fn() {
          run(frame_test.it_should_decode_go_away_frame_test)
        }),
        it("it should return error for zero window update", fn() {
          run(frame_test.it_should_return_error_for_zero_window_update_test)
        }),
        it("it should decode padded data frame", fn() {
          run(frame_test.it_should_decode_padded_data_frame_test)
        }),
        it("it should decode unknown frame", fn() {
          run(frame_test.it_should_decode_unknown_frame_test)
        }),
        it("it should return error for small max frame size", fn() {
          run(frame_test.it_should_return_error_for_small_max_frame_size_test)
        }),
        it("it should decode settings in order", fn() {
          run(frame_test.it_should_decode_settings_in_order_test)
        }),
        it("it should return error for oversized frame", fn() {
          run(frame_test.it_should_return_error_for_oversized_frame_test)
        }),
      ]),
    ),
    Suite(
      "vendored_mist/mist/http2/flow_control",
      describe("vendored_mist/mist/http2/flow_control", [
        it("it should send up to the smaller window", fn() {
          run(flow_control_test.it_should_send_up_to_the_smaller_window_test)
        }),
        it("it should send nothing with a negative window", fn() {
          run(
            flow_control_test.it_should_send_nothing_with_a_negative_window_test,
          )
        }),
      ]),
    ),
    Suite(
      "vendored_mist/mist/file",
      describe("vendored_mist/mist/file", [
        it("it should read nothing at end of file", fn() {
          run(file_test.it_should_read_nothing_at_end_of_file_test)
        }),
      ]),
    ),
    Suite(
      "vendored_glisten/glisten",
      describe("vendored_glisten/glisten", [
        it("it echoes messages", fn() {
          run(glisten_test.it_echoes_messages_test)
        }),
        it("it accepts from the pool", fn() {
          run(glisten_test.it_accepts_from_the_pool_test)
        }),
        it("it keeps the default socket buffer", fn() {
          run(glisten_test.it_keeps_the_default_socket_buffer_test)
        }),
        it("it sets the socket buffer size", fn() {
          run(glisten_test.it_sets_the_socket_buffer_size_test)
        }),
        it("ip address to string", fn() {
          run(glisten_test.ip_address_to_string_test)
        }),
        it("merge type lists", fn() { run(glisten_test.merge_type_lists_test) }),
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
