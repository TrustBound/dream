import dream_http_client/client.{
  LogDebug, LogError, LogInfo, LogNone, LogWarning,
}
import gleeunit/should

pub fn transport_config_has_correct_defaults_test() {
  let config = client.transport_config()

  client.get_max_connections(config) |> should.equal(50)
  client.get_idle_timeout(config) |> should.equal(60_000)
  client.get_default_connect_timeout(config) |> should.equal(15_000)
  client.get_domain_lookup_timeout(config) |> should.equal(5000)
  client.get_tls_handshake_timeout(config) |> should.equal(10_000)
  client.get_retry(config) |> should.equal(3)
  client.get_retry_timeout(config) |> should.equal(1000)
  client.get_keepalive(config) |> should.equal(30_000)
  client.get_keepalive_tolerance(config) |> should.equal(3)
  client.get_max_concurrent_streams(config) |> should.equal(100)
  client.get_initial_connection_window_size(config) |> should.equal(65_535)
  client.get_initial_stream_window_size(config) |> should.equal(65_535)
  client.get_closing_timeout(config) |> should.equal(15_000)
  client.get_log_level(config) |> should.equal(LogInfo)
}

pub fn max_connections_sets_value_test() {
  let config = client.transport_config()
  let updated = client.max_connections(config, 200)
  client.get_max_connections(updated) |> should.equal(200)
}

pub fn max_connections_accepts_one_test() {
  let config = client.transport_config()
  let updated = client.max_connections(config, 1)
  client.get_max_connections(updated) |> should.equal(1)
}

pub fn idle_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.idle_timeout(config, 120_000)
  client.get_idle_timeout(updated) |> should.equal(120_000)
}

pub fn default_connect_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.default_connect_timeout(config, 30_000)
  client.get_default_connect_timeout(updated) |> should.equal(30_000)
}

pub fn domain_lookup_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.domain_lookup_timeout(config, 10_000)
  client.get_domain_lookup_timeout(updated) |> should.equal(10_000)
}

pub fn tls_handshake_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.tls_handshake_timeout(config, 20_000)
  client.get_tls_handshake_timeout(updated) |> should.equal(20_000)
}

pub fn retry_sets_value_test() {
  let config = client.transport_config()
  let updated = client.retry(config, 5)
  client.get_retry(updated) |> should.equal(5)
}

pub fn retry_accepts_zero_test() {
  let config = client.transport_config()
  let updated = client.retry(config, 0)
  client.get_retry(updated) |> should.equal(0)
}

pub fn retry_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.retry_timeout(config, 5000)
  client.get_retry_timeout(updated) |> should.equal(5000)
}

pub fn keepalive_sets_value_test() {
  let config = client.transport_config()
  let updated = client.keepalive(config, 60_000)
  client.get_keepalive(updated) |> should.equal(60_000)
}

pub fn keepalive_tolerance_sets_value_test() {
  let config = client.transport_config()
  let updated = client.keepalive_tolerance(config, 5)
  client.get_keepalive_tolerance(updated) |> should.equal(5)
}

pub fn keepalive_tolerance_accepts_zero_test() {
  let config = client.transport_config()
  let updated = client.keepalive_tolerance(config, 0)
  client.get_keepalive_tolerance(updated) |> should.equal(0)
}

pub fn max_concurrent_streams_sets_value_test() {
  let config = client.transport_config()
  let updated = client.max_concurrent_streams(config, 500)
  client.get_max_concurrent_streams(updated) |> should.equal(500)
}

pub fn max_concurrent_streams_accepts_one_test() {
  let config = client.transport_config()
  let updated = client.max_concurrent_streams(config, 1)
  client.get_max_concurrent_streams(updated) |> should.equal(1)
}

pub fn initial_connection_window_size_sets_value_test() {
  let config = client.transport_config()
  let updated = client.initial_connection_window_size(config, 131_070)
  client.get_initial_connection_window_size(updated) |> should.equal(131_070)
}

pub fn initial_stream_window_size_sets_value_test() {
  let config = client.transport_config()
  let updated = client.initial_stream_window_size(config, 131_070)
  client.get_initial_stream_window_size(updated) |> should.equal(131_070)
}

pub fn closing_timeout_sets_value_test() {
  let config = client.transport_config()
  let updated = client.closing_timeout(config, 30_000)
  client.get_closing_timeout(updated) |> should.equal(30_000)
}

pub fn log_level_defaults_to_info_test() {
  let config = client.transport_config()
  client.get_log_level(config) |> should.equal(LogInfo)
}

pub fn log_level_sets_debug_test() {
  let config = client.transport_config()
  let updated = client.log_level(config, LogDebug)
  client.get_log_level(updated) |> should.equal(LogDebug)
}

pub fn log_level_sets_warning_test() {
  let config = client.transport_config()
  let updated = client.log_level(config, LogWarning)
  client.get_log_level(updated) |> should.equal(LogWarning)
}

pub fn log_level_sets_error_test() {
  let config = client.transport_config()
  let updated = client.log_level(config, LogError)
  client.get_log_level(updated) |> should.equal(LogError)
}

pub fn log_level_sets_none_test() {
  let config = client.transport_config()
  let updated = client.log_level(config, LogNone)
  client.get_log_level(updated) |> should.equal(LogNone)
}

pub fn transport_config_builder_chain_sets_all_values_test() {
  let config =
    client.transport_config()
    |> client.max_connections(200)
    |> client.idle_timeout(120_000)
    |> client.default_connect_timeout(30_000)
    |> client.domain_lookup_timeout(10_000)
    |> client.tls_handshake_timeout(20_000)
    |> client.retry(5)
    |> client.retry_timeout(5000)
    |> client.keepalive(60_000)
    |> client.keepalive_tolerance(5)
    |> client.max_concurrent_streams(500)
    |> client.initial_connection_window_size(131_070)
    |> client.initial_stream_window_size(131_070)
    |> client.closing_timeout(30_000)
    |> client.log_level(LogWarning)

  client.get_max_connections(config) |> should.equal(200)
  client.get_idle_timeout(config) |> should.equal(120_000)
  client.get_default_connect_timeout(config) |> should.equal(30_000)
  client.get_domain_lookup_timeout(config) |> should.equal(10_000)
  client.get_tls_handshake_timeout(config) |> should.equal(20_000)
  client.get_retry(config) |> should.equal(5)
  client.get_retry_timeout(config) |> should.equal(5000)
  client.get_keepalive(config) |> should.equal(60_000)
  client.get_keepalive_tolerance(config) |> should.equal(5)
  client.get_max_concurrent_streams(config) |> should.equal(500)
  client.get_initial_connection_window_size(config) |> should.equal(131_070)
  client.get_initial_stream_window_size(config) |> should.equal(131_070)
  client.get_closing_timeout(config) |> should.equal(30_000)
  client.get_log_level(config) |> should.equal(LogWarning)
}

pub fn configure_transport_applies_without_error_test() {
  let config = client.transport_config()
  let result = client.configure_transport(config)
  result |> should.equal(Nil)
}
