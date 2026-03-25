import dream_http_client/client
import gleeunit/should

pub fn transport_config_has_correct_defaults_test() {
  // Arrange & Act
  let config = client.transport_config()

  // Assert
  client.get_max_sessions(config) |> should.equal(100)
  client.get_max_pipeline_length(config) |> should.equal(0)
  client.get_keep_alive_timeout(config) |> should.equal(60_000)
  client.get_max_keep_alive_length(config) |> should.equal(100)
}

pub fn max_sessions_sets_value_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let updated = client.max_sessions(config, 200)

  // Assert
  client.get_max_sessions(updated) |> should.equal(200)
}

pub fn max_sessions_accepts_zero_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let updated = client.max_sessions(config, 0)

  // Assert
  client.get_max_sessions(updated) |> should.equal(0)
}

pub fn max_pipeline_length_sets_value_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let updated = client.max_pipeline_length(config, 5)

  // Assert
  client.get_max_pipeline_length(updated) |> should.equal(5)
}

pub fn keep_alive_timeout_sets_value_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let updated = client.keep_alive_timeout(config, 120_000)

  // Assert
  client.get_keep_alive_timeout(updated) |> should.equal(120_000)
}

pub fn max_keep_alive_length_sets_value_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let updated = client.max_keep_alive_length(config, 50)

  // Assert
  client.get_max_keep_alive_length(updated) |> should.equal(50)
}

pub fn transport_config_builder_chain_sets_all_values_test() {
  // Arrange & Act
  let config =
    client.transport_config()
    |> client.max_sessions(200)
    |> client.max_pipeline_length(5)
    |> client.keep_alive_timeout(120_000)
    |> client.max_keep_alive_length(50)

  // Assert
  client.get_max_sessions(config) |> should.equal(200)
  client.get_max_pipeline_length(config) |> should.equal(5)
  client.get_keep_alive_timeout(config) |> should.equal(120_000)
  client.get_max_keep_alive_length(config) |> should.equal(50)
}

pub fn configure_transport_applies_without_error_test() {
  // Arrange
  let config = client.transport_config()

  // Act
  let result = client.configure_transport(config)

  // Assert
  result |> should.equal(Nil)
}
