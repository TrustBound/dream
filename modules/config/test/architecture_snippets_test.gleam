//// Tests for the dream_config snippet in docs/reference/architecture.md.
////
//// Each test sets DATABASE_URL and PORT itself and unsets them at the end.

import envoy
import gleeunit/should
import snippets/architecture_config.{AppConfig}

pub fn load_config_reads_database_url_and_port_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.set("PORT", "8080")

  // Act
  let result = architecture_config.load_config()
  envoy.unset("DATABASE_URL")
  envoy.unset("PORT")

  // Assert
  result
  |> should.equal(
    Ok(AppConfig(database_url: "postgres://localhost/app", port: 8080)),
  )
}

pub fn load_config_uses_port_3000_when_port_is_not_set_test() {
  // Arrange
  envoy.set("DATABASE_URL", "postgres://localhost/app")
  envoy.unset("PORT")

  // Act
  let result = architecture_config.load_config()
  envoy.unset("DATABASE_URL")

  // Assert
  result
  |> should.equal(
    Ok(AppConfig(database_url: "postgres://localhost/app", port: 3000)),
  )
}

pub fn load_config_without_database_url_returns_error_test() {
  // Arrange
  envoy.unset("DATABASE_URL")

  // Act
  let result = architecture_config.load_config()

  // Assert
  result
  |> should.equal(Error("Required environment variable not set: DATABASE_URL"))
}
