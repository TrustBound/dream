//// Tests for the code blocks in the dream_json README.

import gleam/time/timestamp
import gleeunit/should
import snippets/optional_values
import snippets/quick_start
import snippets/timestamps

pub fn user_json_encodes_optional_fields_and_the_timestamp_test() {
  // Arrange
  let created_at = timestamp.from_unix_seconds(1_700_000_000)

  // Act
  let json = quick_start.user_json(created_at)

  // Assert
  json
  |> should.equal(
    "{\"name\":\"Alice\",\"email\":\"alice@example.com\",\"age\":null,\"created_at\":\"Timestamp(1700000000, 0)\"}",
  )
}

pub fn profile_json_encodes_some_as_the_value_and_none_as_null_test() {
  // Act
  let json = optional_values.profile_json()

  // Assert
  json
  |> should.equal(
    "{\"name\":\"Alice\",\"middle_name\":null,\"nickname\":\"Al\",\"age\":30,\"score\":null,\"is_active\":true}",
  )
}

pub fn audit_json_encodes_the_timestamp_and_null_test() {
  // Arrange
  let created_at = timestamp.from_unix_seconds(1_700_000_000)

  // Act
  let json = timestamps.audit_json(created_at)

  // Assert
  json
  |> should.equal(
    "{\"created_at\":\"Timestamp(1700000000, 0)\",\"deleted_at\":null}",
  )
}
