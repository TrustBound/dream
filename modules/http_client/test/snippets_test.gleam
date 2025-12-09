//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// We use dream_mock_server (localhost:9876) to avoid external dependencies.

import gleeunit/should
import snippets/blocking_request
import snippets/matching_config
import snippets/post_json
import snippets/recording_basic
import snippets/recording_playback
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
  let config = matching_config.create_default_matching()
  config.match_url |> should.be_true()
}

pub fn matching_config_custom_test() {
  let config = matching_config.create_custom_matching()
  config.match_method |> should.be_true()
  config.match_url |> should.be_true()
  config.match_headers |> should.be_false()
  config.match_body |> should.be_false()
}

pub fn recording_playback_test() {
  recording_playback.test_with_playback()
  |> should.be_ok()
  |> should.equal("Test data")
}

pub fn stream_messages_basic_test() {
  stream_messages_basic.stream_and_print()
  |> should.be_ok()
}
