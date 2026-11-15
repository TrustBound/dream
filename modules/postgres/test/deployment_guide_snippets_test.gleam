//// Tests for the connection pool snippet in docs/guides/deployment.md.
////
//// The test needs no database: it checks the config that the snippet
//// makes.

import gleeunit/should
import snippets/deployment_guide_postgres

pub fn create_database_config_sets_pool_size_15_test() {
  // Arrange
  let config = deployment_guide_postgres.create_database_config()

  // Act
  let pool_size = config.pool_size

  // Assert
  pool_size |> should.equal(15)
}
