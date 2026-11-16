//// Tests for the code blocks in this module's README.md.
////
//// Each test sets the environment variables it needs and unsets them at the
//// end.

import envoy
import gleam/option
import gleeunit/should
import snippets/readme_boolean_values
import snippets/readme_load_env_files
import snippets/readme_optional_values
import snippets/readme_quick_start.{Settings}
import snippets/readme_required_values.{AppConfig}

pub fn quick_start_reads_required_and_optional_values_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.set("PORT", "8080")
  envoy.set("DEBUG", "true")
  envoy.unset("API_KEY")

  // Act
  let result = readme_quick_start.load_settings()
  envoy.unset("DATABASE_URL")
  envoy.unset("PORT")
  envoy.unset("DEBUG")

  // Assert
  result
  |> should.equal(
    Ok(Settings(
      database_url: "postgres://localhost/app",
      port: 8080,
      debug_mode: True,
      api_key: "default-key",
    )),
  )
}

pub fn quick_start_fails_when_port_is_not_set_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.unset("PORT")

  // Act
  let result = readme_quick_start.load_settings()
  envoy.unset("DATABASE_URL")

  // Assert
  result
  |> should.equal(Error("Required environment variable not set: PORT"))
}

pub fn load_env_files_sets_the_variables_from_the_file_test() {
  // Arrange
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Act
  let _loaded = readme_load_env_files.load_env_files("test/fixtures/myapp.env")
  let greeting = envoy.get("DREAM_CONFIG_SNIPPET_GREETING")
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Assert
  greeting |> should.equal(Ok("hello from myapp.env"))
}

pub fn load_env_files_returns_ok_test() {
  // Act
  let result = readme_load_env_files.load_env_files("test/fixtures/myapp.env")
  envoy.unset("DREAM_CONFIG_SNIPPET_GREETING")

  // Assert
  result |> should.equal(Ok(Nil))
}

pub fn load_config_reads_database_url_and_port_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.set("PORT", "8080")

  // Act
  let result = readme_required_values.load_config()
  envoy.unset("DATABASE_URL")
  envoy.unset("PORT")

  // Assert
  result
  |> should.equal(
    Ok(AppConfig(database_url: "postgres://localhost/app", port: 8080)),
  )
}

pub fn load_config_fails_when_database_url_is_not_set_test() {
  // Arrange
  envoy.unset("DATABASE_URL")
  envoy.set("PORT", "8080")

  // Act
  let result = readme_required_values.load_config()
  envoy.unset("PORT")

  // Assert
  result
  |> should.equal(Error("Required environment variable not set: DATABASE_URL"))
}

pub fn load_config_fails_when_port_is_not_an_integer_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.set("PORT", "eighty")

  // Act
  let result = readme_required_values.load_config()
  envoy.unset("DATABASE_URL")
  envoy.unset("PORT")

  // Assert
  result |> should.equal(Error("Environment variable PORT must be an integer"))
}

pub fn read_optional_values_reads_set_values_test() {
  // Arrange
  envoy.set("API_KEY", "example-api-key")
  envoy.set("PORT", "8080")

  // Act
  let result = readme_optional_values.read_optional_values()
  envoy.unset("API_KEY")
  envoy.unset("PORT")

  // Assert
  result |> should.equal(#(option.Some("example-api-key"), 8080))
}

pub fn read_optional_values_uses_defaults_when_not_set_test() {
  // Arrange
  envoy.unset("API_KEY")
  envoy.unset("PORT")

  // Act
  let result = readme_optional_values.read_optional_values()

  // Assert
  result |> should.equal(#(option.None, 3000))
}

pub fn log_level_is_debug_when_debug_is_yes_test() {
  // Arrange
  envoy.set("DEBUG", "yes")

  // Act
  let result = readme_boolean_values.log_level()
  envoy.unset("DEBUG")

  // Assert
  result |> should.equal("debug")
}

pub fn log_level_is_info_when_debug_is_not_set_test() {
  // Arrange
  envoy.unset("DEBUG")

  // Act
  let result = readme_boolean_values.log_level()

  // Assert
  result |> should.equal("info")
}
