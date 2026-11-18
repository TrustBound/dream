//// Tests for the dream_json snippet in docs/reference/architecture.md.

import gleam/option.{None, Some}
import gleeunit/should
import snippets/architecture_json.{Profile}

pub fn profile_to_json_encodes_some_as_the_value_and_none_as_null_test() {
  // Arrange
  let profile = Profile(email: Some("user@example.com"), age: None)

  // Act
  let json = architecture_json.profile_to_json(profile)

  // Assert
  json |> should.equal("{\"email\":\"user@example.com\",\"age\":null}")
}

pub fn profile_to_json_encodes_an_age_test() {
  // Arrange
  let profile = Profile(email: None, age: Some(36))

  // Act
  let json = architecture_json.profile_to_json(profile)

  // Assert
  json |> should.equal("{\"email\":null,\"age\":36}")
}
