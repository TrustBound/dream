//// Test examples from the testing guide that the guide shows without imports.

import dream_test/assertions/should.{be_ok, be_some, equal, or_fail_with, should}
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/string
import snippets/testing_guide_extract_user_name.{extract_user_name}
import snippets/testing_guide_user.{
  type User, User, create_user, find_user, list_users, validate_email,
  validate_user,
}

pub fn chaining_tests() -> UnitTest {
  describe("chaining matchers", [
    it("finds user 1", fn() {
      let user = User(id: 1, name: "Alice", email: "alice@example.com")

      // Extract from Option then assert
      find_user(1)
      |> should()
      // Unwraps Option, passes inner value
      |> be_some()
      // Asserts on the unwrapped value
      |> equal(user)
      |> or_fail_with("User should exist")
    }),
    it("accepts a valid email", fn() {
      // Extract from Result then assert
      validate_email("test@example.com")
      |> should()
      // Unwraps Result, passes Ok value
      |> be_ok()
      // Asserts on the unwrapped value
      |> equal("test@example.com")
      |> or_fail_with("Email should be valid")
    }),
  ])
}

pub fn custom_matcher_tests() -> UnitTest {
  it("reads the name from a valid user", fn() {
    let json_body =
      "{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}"

    validate_user(json_body)
    |> should()
    |> extract_user_name(fn(user) { user.name })
    |> equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}

pub fn black_box_tests() -> UnitTest {
  describe("find_user", [
    // ✅ Good - tests observable behavior
    it("returns user by ID", fn() {
      find_user(1)
      |> should()
      |> be_some()
      |> or_fail_with("Should find user")
    }),
    // ❌ Bad - tests internal implementation
    it("stores Alice first in the user list", fn() {
      list_users()
      |> list.first()
      |> should()
      |> be_ok()
      |> extract_name()
      |> equal("Alice")
      |> or_fail_with("Alice should be first")
    }),
  ])
}

pub fn one_assertion_tests() -> UnitTest {
  // ✅ Good - focused tests
  describe("create_user", [
    it("returns created user", fn() {
      create_user("Alice", "alice@example.com")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create user")
    }),
    it("sets correct name", fn() {
      create_user("Alice", "alice@example.com")
      |> should()
      |> be_ok()
      |> extract_name()
      |> equal("Alice")
      |> or_fail_with("Name should be Alice")
    }),
  ])
}

pub fn multiple_assertions_test() -> UnitTest {
  // ❌ Bad - multiple assertions
  it("creates user correctly", fn() {
    let result = create_user("Alice", "alice@example.com")
    let _ = result |> should() |> be_ok() |> or_fail_with("Should create user")
    // And then another assertion...
    result
    |> should()
    |> be_ok()
    |> extract_name()
    |> equal("Alice")
    |> or_fail_with("Name should be Alice")
  })
}

pub fn arrange_act_assert_test() -> UnitTest {
  it("uppercases string", fn() {
    // Arrange
    let input = "hello"

    // Act
    let result = string.uppercase(input)

    // Assert
    result
    |> should()
    |> equal("HELLO")
    |> or_fail_with("Should uppercase")
  })
}

/// Extract the name from a user, for chaining.
pub fn extract_name(result: MatchResult(User)) -> MatchResult(String) {
  case result {
    MatchOk(user) -> MatchOk(user.name)
    MatchFailed(failure) -> MatchFailed(failure)
  }
}
