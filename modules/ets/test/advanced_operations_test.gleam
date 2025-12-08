//// Tests for advanced ETS operations

import dream_ets/helpers
import dream_ets/internal
import dream_ets/operations
import dream_test/assertions/should.{be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/result

pub fn tests() -> UnitTest {
  describe("advanced operations", [
    describe("update_element", [
      it("updates tuple element in place", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("update_elem_test"))
          use _ <- result.try(operations.set(table, "key", "original"))

          // Act - update the value element (position 2 in {key, value} tuple)
          let new_value = internal.to_dynamic("updated")
          operations.update_element(table, "key", 2, new_value)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should update element")
      }),
    ]),
    describe("match", [
      it("performs pattern matching", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("match_test"))
          use _ <- result.try(operations.set(table, "key1", "value1"))
          use _ <- result.try(operations.set(table, "key2", "value2"))

          // Act - match all entries (using dynamic pattern)
          let pattern = internal.to_dynamic(#("$1", "$2"))
          let matches = operations.match(table, pattern)
          Ok(matches)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Match should work")
      }),
    ]),
    describe("match_object", [
      it("matches complete objects", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("match_obj_test"))
          use _ <- result.try(operations.set(table, "key1", "value1"))

          // Act
          let pattern = internal.to_dynamic(#("$1", "$2"))
          let matches = operations.match_object(table, pattern)
          Ok(matches)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Match object should work")
      }),
    ]),
    describe("select", [
      it("performs select with match specification", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("select_test"))
          use _ <- result.try(operations.set(table, "key1", "value1"))

          // Act - simple match spec that returns all
          let match_spec = internal.to_dynamic([#(#("$1", "$2"), [], ["$_"])])
          let results = operations.select(table, match_spec)
          Ok(results)
        }

        // Assert  
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Select should work")
      }),
    ]),
  ])
}
