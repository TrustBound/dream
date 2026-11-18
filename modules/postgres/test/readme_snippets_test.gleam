//// Tests for the code blocks in this module's README.md.
////
//// These tests need no database. They check the config each builder makes
//// and how query results become values. The functions that connect or run a
//// query (connect_database, connect_from_url, find_user, list_users,
//// connect_production) need a running PostgreSQL, so they are only
//// compiled.

import dream_postgres/query
import gleam/option
import gleeunit/should
import pog
import snippets/readme_connection_builder
import snippets/readme_connection_from_url
import snippets/readme_connection_setup
import snippets/readme_error_handling
import snippets/readme_query_execution
import snippets/readme_query_result_helpers

// ============================================================================
// Connection Setup
// ============================================================================

pub fn database_config_sets_every_value_test() {
  // Arrange
  let config = readme_connection_setup.database_config()

  // Act
  let values = #(
    config.host,
    config.port,
    config.database,
    config.user,
    config.password,
    config.pool_size,
  )

  // Assert
  values
  |> should.equal(#(
    "localhost",
    5432,
    "myapp",
    "postgres",
    option.Some("secret"),
    15,
  ))
}

// ============================================================================
// Or from URL
// ============================================================================

pub fn describe_url_with_the_readme_url_names_database_and_host_test() {
  // Act
  let description =
    readme_connection_from_url.describe_url(
      "postgresql://user:pass@localhost:5432/myapp",
    )

  // Assert
  description |> should.equal("Database myapp on localhost")
}

pub fn describe_url_with_an_unsupported_parameter_names_it_test() {
  // Act
  let description =
    readme_connection_from_url.describe_url(
      "postgresql://user:pass@localhost:5432/myapp?connect_timeout=10",
    )

  // Assert
  description |> should.equal("Unsupported parameter: connect_timeout")
}

pub fn describe_url_with_a_missing_database_inspects_the_error_test() {
  // Act
  let description =
    readme_connection_from_url.describe_url(
      "postgresql://user:pass@localhost:5432",
    )

  // Assert
  description |> should.equal("Invalid URL: MissingDatabase")
}

// ============================================================================
// Query Execution
// ============================================================================

pub fn describe_user_with_a_row_describes_the_user_test() {
  // Arrange
  let result =
    Ok(
      pog.Returned(count: 1, rows: [
        readme_query_execution.User(id: 7, name: "Ada"),
      ]),
    )

  // Act
  let description = readme_query_execution.describe_user(result)

  // Assert
  description |> should.equal("User 7: Ada")
}

pub fn describe_user_with_no_rows_returns_no_such_user_test() {
  // Arrange
  let result = Ok(pog.Returned(count: 0, rows: []))

  // Act
  let description = readme_query_execution.describe_user(result)

  // Assert
  description |> should.equal("No such user")
}

pub fn describe_user_with_a_query_error_returns_failure_test() {
  // Arrange
  let result = Error(pog.ConnectionUnavailable)

  // Act
  let description = readme_query_execution.describe_user(result)

  // Assert
  description |> should.equal("The database query failed")
}

pub fn describe_user_count_counts_the_rows_test() {
  // Arrange
  let result =
    Ok(
      pog.Returned(count: 2, rows: [
        readme_query_execution.User(id: 1, name: "Ada"),
        readme_query_execution.User(id: 2, name: "Grace"),
      ]),
    )

  // Act
  let description = readme_query_execution.describe_user_count(result)

  // Assert
  description |> should.equal("2 users")
}

pub fn describe_user_count_with_a_query_error_returns_failure_test() {
  // Arrange
  let result = Error(pog.ConnectionUnavailable)

  // Act
  let description = readme_query_execution.describe_user_count(result)

  // Assert
  description
  |> should.equal("The database query failed: DatabaseError")
}

// ============================================================================
// Connection Builder Pattern
// ============================================================================

pub fn production_config_sets_every_value_test() {
  // Arrange
  let config = readme_connection_builder.production_config()

  // Act
  let values = #(
    config.host,
    config.port,
    config.database,
    config.user,
    config.password,
    config.pool_size,
  )

  // Assert
  values
  |> should.equal(#(
    "localhost",
    5432,
    "myapp_prod",
    "postgres",
    option.Some("secret"),
    20,
  ))
}

// ============================================================================
// Query Result Helpers
// ============================================================================

pub fn user_from_result_with_a_row_returns_the_user_test() {
  // Arrange
  let user = readme_query_result_helpers.User(id: 7, name: "Ada")
  let result = Ok(pog.Returned(count: 1, rows: [user]))

  // Act
  let found = readme_query_result_helpers.user_from_result(result)

  // Assert
  found
  |> should.equal(Ok(readme_query_result_helpers.User(id: 7, name: "Ada")))
}

pub fn user_from_result_with_no_rows_returns_user_not_found_test() {
  // Arrange
  let result = Ok(pog.Returned(count: 0, rows: []))

  // Act
  let found = readme_query_result_helpers.user_from_result(result)

  // Assert
  found |> should.equal(Error("User not found"))
}

pub fn user_from_result_with_a_query_error_returns_database_error_test() {
  // Arrange
  let result = Error(pog.ConnectionUnavailable)

  // Act
  let found = readme_query_result_helpers.user_from_result(result)

  // Assert
  found |> should.equal(Error("Database error"))
}

pub fn user_names_from_result_returns_every_name_test() {
  // Arrange
  let result =
    Ok(
      pog.Returned(count: 2, rows: [
        readme_query_result_helpers.User(id: 1, name: "Ada"),
        readme_query_result_helpers.User(id: 2, name: "Grace"),
      ]),
    )

  // Act
  let names = readme_query_result_helpers.user_names_from_result(result)

  // Assert
  names |> should.equal(Ok(["Ada", "Grace"]))
}

pub fn user_names_from_result_with_a_query_error_returns_database_error_test() {
  // Arrange
  let result = Error(pog.ConnectionUnavailable)

  // Act
  let names = readme_query_result_helpers.user_names_from_result(result)

  // Assert
  names |> should.equal(Error("Database error: DatabaseError"))
}

// ============================================================================
// Error Handling
// ============================================================================

pub fn explain_query_error_for_not_found_test() {
  // Act
  let explanation = readme_error_handling.explain_query_error(query.NotFound)

  // Assert
  explanation |> should.equal("The query returned no rows")
}

pub fn explain_query_error_for_database_error_test() {
  // Act
  let explanation =
    readme_error_handling.explain_query_error(query.DatabaseError)

  // Assert
  explanation |> should.equal("The query failed")
}
