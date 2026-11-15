//// Tests for the dream_postgres snippet in docs/learn/02-building-api.md.
////
//// These tests need no database: they check the config that the snippet
//// builds. initialize_services needs a running PostgreSQL, so it is only
//// compiled.

import gleam/option.{Some}
import gleeunit/should
import snippets/learn_building_api_services

pub fn create_database_config_sets_host_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let host = config.host

  // Assert
  host |> should.equal("localhost")
}

pub fn create_database_config_sets_port_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let port = config.port

  // Assert
  port |> should.equal(5432)
}

pub fn create_database_config_sets_database_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let database = config.database

  // Assert
  database |> should.equal("myapp")
}

pub fn create_database_config_sets_user_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let user = config.user

  // Assert
  user |> should.equal("postgres")
}

pub fn create_database_config_sets_password_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let password = config.password

  // Assert
  password |> should.equal(Some("postgres"))
}

pub fn create_database_config_sets_pool_size_test() {
  // Arrange
  let config = learn_building_api_services.create_database_config()

  // Act
  let pool_size = config.pool_size

  // Assert
  pool_size |> should.equal(10)
}
