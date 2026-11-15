//// Tests for the dream_postgres snippet in docs/reference/architecture.md.
////
//// These tests need no database: they check the config the builder makes
//// and how query results become values. connect_database and
//// find_user_name need a running PostgreSQL, so they are only compiled.

import gleeunit/should
import pog
import snippets/architecture_postgres

pub fn create_database_config_sets_host_test() {
  // Arrange
  let config = architecture_postgres.create_database_config()

  // Act
  let host = config.host

  // Assert
  host |> should.equal("localhost")
}

pub fn create_database_config_sets_database_test() {
  // Arrange
  let config = architecture_postgres.create_database_config()

  // Act
  let database = config.database

  // Assert
  database |> should.equal("app")
}

pub fn create_database_config_sets_pool_size_test() {
  // Arrange
  let config = architecture_postgres.create_database_config()

  // Act
  let pool_size = config.pool_size

  // Assert
  pool_size |> should.equal(10)
}

pub fn describe_user_name_with_a_row_returns_the_name_test() {
  // Arrange
  let result = Ok(pog.Returned(count: 1, rows: ["Ada"]))

  // Act
  let description = architecture_postgres.describe_user_name(result)

  // Assert
  description |> should.equal("Ada")
}

pub fn describe_user_name_with_no_rows_returns_no_such_user_test() {
  // Arrange
  let result = Ok(pog.Returned(count: 0, rows: []))

  // Act
  let description = architecture_postgres.describe_user_name(result)

  // Assert
  description |> should.equal("No such user")
}

pub fn describe_user_name_with_a_query_error_returns_failure_test() {
  // Arrange
  let result = Error(pog.ConnectionUnavailable)

  // Act
  let description = architecture_postgres.describe_user_name(result)

  // Assert
  description |> should.equal("The database query failed")
}
