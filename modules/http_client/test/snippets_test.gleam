//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// We use dream_mock_server (localhost:9876) to avoid external dependencies.

import dream_http_client/recording
import gleam/http
import gleam/option
import gleeunit/should
import snippets/blocking_request
import snippets/matching_config
import snippets/post_json
import snippets/recording_ambiguous_match
import snippets/recording_basic
import snippets/recording_playback
import snippets/recording_response_transformer
import snippets/recording_transformer
import snippets/request_builder
import snippets/stream_messages_basic
import snippets/stream_yielder_basic
import snippets/timeout_config

pub fn blocking_request_test() {
  blocking_request.simple_get()
  |> should.be_ok()
}

pub fn post_json_test() {
  post_json.post_user()
  |> should.be_ok()
}

pub fn request_builder_test() {
  request_builder.build_complex_request()
  |> should.be_ok()
}

pub fn stream_yielder_test() {
  stream_yielder_basic.stream_and_process()
  |> should.be_ok()
}

pub fn timeout_short_test() {
  timeout_config.short_timeout()
  |> should.be_ok()
}

pub fn recording_basic_test() {
  recording_basic.record_and_playback()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn matching_config_default_test() {
  let key = matching_config.create_default_key()
  let req =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )
  key(req) |> should.not_equal("")
}

pub fn matching_config_custom_test() {
  let key = matching_config.create_custom_key()
  let req1 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("X-Test", "one")],
      body: "a",
    )
  let req2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("X-Test", "two")],
      body: "b",
    )
  key(req1) |> should.not_equal(key(req2))
}

pub fn recording_playback_test() {
  recording_playback.test_with_playback()
  |> should.be_ok()
  |> should.equal("Test data")
}

pub fn recording_transformer_test() {
  recording_transformer.transformer_scrubs_and_still_matches()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn recording_ambiguous_match_test() {
  recording_ambiguous_match.ambiguous_playback_returns_error()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn recording_response_transformer_test() {
  recording_response_transformer.response_transformer_scrubs_before_persistence()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn stream_messages_basic_test() {
  stream_messages_basic.stream_and_print()
  |> should.be_ok()
}
