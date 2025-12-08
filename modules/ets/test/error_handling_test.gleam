//// Tests for error handling in dream_ets.

import dream_ets/config
import dream_ets/operations
import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import gleam/result

pub fn tests() -> UnitTest {
  describe("error_handling", [
    describe("create", [
      it("returns InvalidKey error for missing key encoder", fn() {
        // Arrange
        let incomplete_config = config.new("test_missing_key_encoder")

        // Act
        let result = config.create(incomplete_config)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should return error")
      }),
      it("returns InvalidValue error for missing value encoder", fn() {
        // Arrange
        let incomplete_config =
          config.new("test_missing_value_encoder")
          |> config.key_string()

        // Act
        let result = config.create(incomplete_config)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should return error")
      }),
      it("returns TableAlreadyExists error for duplicate name", fn() {
        // Arrange
        let _table1 =
          config.new("test_duplicate_name")
          |> config.key_string()
          |> config.value_string()
          |> config.create()

        let config2 =
          config.new("test_duplicate_name")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(config2)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should return error")
      }),
    ]),
    describe("get", [
      it("returns None for empty table", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_get_empty")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.get(table, "nonexistent")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.None)
        |> or_fail_with("Should return None")
      }),
    ]),
    describe("delete", [
      it("succeeds for nonexistent key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_delete_nonexistent")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.delete(table, "nonexistent")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should succeed even for nonexistent key")
      }),
    ]),
  ])
}
