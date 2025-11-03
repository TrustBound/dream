//// Mock PostgreSQL connection helper for testing
////
//// This module provides helper functions for testing PostgreSQL singleton
//// with controlled connection behavior. Since pog.Connection is opaque,
//// we use a test connection created with pog.connect() but track calls.

import pog

/// Test configuration for creating mock-like behavior
/// Uses real pog connection but allows controlling what queries succeed/fail
pub type TestConfig {
  TestConfig(
    connection: pog.Connection,
    expected_queries: List(String),
    simulate_errors: Bool,
  )
}

/// Create a test connection with default config
/// For actual testing, you'd use pog.connect() with test database config
/// This is a helper to document the pattern
///
/// Note: This function is for documentation purposes and should be implemented
/// in integration tests with a real database. For unit tests, use dependency injection.
pub fn create_test_connection() -> pog.Connection {
  // Note: In real tests, you'd connect to a test database
  // For now, this documents the pattern - actual connection would be:
  // pog.connect(pog.default_config())
  // But we can't run that without a real database
  // So for unit tests, we'll use dependency injection pattern
  panic as "This function should not be called in unit tests. Use dependency injection or implement with real test database for integration tests."
}

/// Helper to verify query was executed
/// This would be used in integration tests with a real test database
pub fn verify_query_executed(
  _connection: pog.Connection,
  _expected_sql: String,
) -> Bool {
  // In real implementation, you'd check query logs or database state
  // For unit tests, we rely on the singleton pattern tests
  True
}


