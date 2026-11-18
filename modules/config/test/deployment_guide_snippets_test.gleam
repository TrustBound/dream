//// Tests for the config snippet in docs/guides/deployment.md.
////
//// Each test sets the environment variables it needs, runs load, and
//// removes the variables again.

import envoy
import gleeunit/should
import snippets/deployment_guide_config.{Config}

fn set_environment(port: Result(String, Nil)) -> Nil {
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.set("SECRET_KEY", "example-secret-key")
  case port {
    Ok(value) -> envoy.set("PORT", value)
    Error(Nil) -> envoy.unset("PORT")
  }
}

fn clear_environment() -> Nil {
  envoy.unset("DATABASE_URL")
  envoy.unset("SECRET_KEY")
  envoy.unset("PORT")
}

pub fn load_with_all_variables_returns_config_test() {
  // Arrange
  set_environment(Ok("8080"))

  // Act
  let result = deployment_guide_config.load()
  clear_environment()

  // Assert
  result
  |> should.equal(
    Ok(Config(
      database_url: "postgres://localhost/app",
      port: 8080,
      secret_key: "example-secret-key",
    )),
  )
}

pub fn load_without_port_uses_port_3000_test() {
  // Arrange
  set_environment(Error(Nil))

  // Act
  let result = deployment_guide_config.load()
  clear_environment()

  // Assert
  result
  |> should.equal(
    Ok(Config(
      database_url: "postgres://localhost/app",
      port: 3000,
      secret_key: "example-secret-key",
    )),
  )
}

pub fn load_with_a_port_that_is_not_a_number_returns_error_test() {
  // Arrange
  set_environment(Ok("eighty"))

  // Act
  let result = deployment_guide_config.load()
  clear_environment()

  // Assert
  result |> should.equal(Error("PORT must be a number, got: eighty"))
}

pub fn load_without_database_url_returns_error_test() {
  // Arrange
  set_environment(Ok("8080"))
  envoy.unset("DATABASE_URL")

  // Act
  let result = deployment_guide_config.load()
  clear_environment()

  // Assert
  result |> should.equal(Error("DATABASE_URL not set"))
}

pub fn load_without_secret_key_returns_error_test() {
  // Arrange
  set_environment(Ok("8080"))
  envoy.unset("SECRET_KEY")

  // Act
  let result = deployment_guide_config.load()
  clear_environment()

  // Assert
  result |> should.equal(Error("SECRET_KEY not set"))
}
