//// Tests for the code blocks in the doc comments of `dream_config/loader`.
////
//// Each test sets the environment variables it needs and unsets them at the
//// end.

import envoy
import gleam/option
import gleeunit/should
import snippets/doc_get
import snippets/doc_get_int
import snippets/doc_get_required
import snippets/doc_get_required_int
import snippets/doc_load_dotenv
import snippets/doc_load_dotenv_from

pub fn database_url_at_startup_reads_the_value_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")

  // Act
  let result = doc_load_dotenv.database_url_at_startup()
  envoy.unset("DATABASE_URL")

  // Assert
  result |> should.equal(Ok("postgres://localhost/app"))
}

pub fn load_settings_file_sets_the_variables_from_the_file_test() {
  // Arrange
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Act
  let result =
    doc_load_dotenv_from.load_settings_file("test/fixtures/myapp.env")
  let greeting = envoy.get("DREAM_CONFIG_SNIPPET_GREETING")
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Assert
  result |> should.equal(Ok(Nil))
  greeting |> should.equal(Ok("hello from myapp.env"))
}

pub fn load_settings_file_fails_for_a_missing_file_test() {
  // Act
  let result = doc_load_dotenv_from.load_settings_file("test/fixtures/none.env")

  // Assert
  result
  |> should.equal(Error(
    "Cannot load .env file at test/fixtures/none.env: the file does not exist",
  ))
}

pub fn database_url_reads_the_value_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")

  // Act
  let result = doc_get_required.database_url()
  envoy.unset("DATABASE_URL")

  // Assert
  result |> should.equal(Ok("postgres://localhost/app"))
}

pub fn database_url_fails_when_not_set_test() {
  // Arrange
  envoy.unset("DATABASE_URL")

  // Act
  let result = doc_get_required.database_url()

  // Assert
  result
  |> should.equal(Error(
    "Cannot start the application: Required environment variable not set: DATABASE_URL",
  ))
}

pub fn api_key_is_some_when_set_test() {
  // Arrange
  envoy.set("API_KEY", "example-api-key")

  // Act
  let result = doc_get.api_key()
  envoy.unset("API_KEY")

  // Assert
  result |> should.equal(option.Some("example-api-key"))
}

pub fn api_key_is_none_when_not_set_test() {
  // Arrange
  envoy.unset("API_KEY")

  // Act
  let result = doc_get.api_key()

  // Assert
  result |> should.equal(option.None)
}

pub fn server_port_reads_the_value_test() {
  // Arrange
  envoy.set("PORT", "8080")

  // Act
  let result = doc_get_int.server_port()
  envoy.unset("PORT")

  // Assert
  result |> should.equal(8080)
}

pub fn server_port_defaults_to_3000_when_not_an_integer_test() {
  // Arrange
  envoy.set("PORT", "eighty")

  // Act
  let result = doc_get_int.server_port()
  envoy.unset("PORT")

  // Assert
  result |> should.equal(3000)
}

pub fn listen_address_uses_the_port_test() {
  // Arrange
  envoy.set("PORT", "8080")

  // Act
  let result = doc_get_required_int.listen_address()
  envoy.unset("PORT")

  // Assert
  result |> should.equal(Ok("0.0.0.0:8080"))
}

pub fn listen_address_fails_when_port_is_not_an_integer_test() {
  // Arrange
  envoy.set("PORT", "eighty")

  // Act
  let result = doc_get_required_int.listen_address()
  envoy.unset("PORT")

  // Assert
  result |> should.equal(Error("Environment variable PORT must be an integer"))
}
