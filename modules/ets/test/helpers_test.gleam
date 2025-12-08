//// Tests for helper functions

import dream_ets/helpers
import dream_ets/operations
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import gleam/result

pub fn tests() -> UnitTest {
  describe("helpers", [
    describe("new_string_table", [
      it("creates string-to-string table", fn() {
        // Arrange & Act
        let result = helpers.new_string_table("string_table_test")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create string table")
      }),
      it("creates functional string table", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table(
            "string_table_functional",
          ))
          use _ <- result.try(operations.set(table, "key", "value"))
          operations.get(table, "key")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("value"))
        |> or_fail_with("String table should work correctly")
      }),
    ]),
  ])
}
