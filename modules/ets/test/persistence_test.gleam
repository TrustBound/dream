//// Tests for table persistence operations

import dream_ets/helpers
import dream_ets/operations
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import gleam/result

pub fn tests() -> UnitTest {
  describe("persistence", [
    describe("save_to_file", [
      it("saves table to disk successfully", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("save_test"))
          use _ <- result.try(operations.set(table, "key1", "value1"))
          use _ <- result.try(operations.set(table, "key2", "value2"))

          // Act
          operations.save_to_file(table, "/tmp/dream_ets_save_test.ets")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should save table to disk")
      }),
      it("data persists after save", fn() {
        // Arrange
        let result = {
          use table <- result.try(helpers.new_string_table("persist_test"))
          use _ <- result.try(operations.set(table, "important", "data"))
          use _ <- result.try(operations.save_to_file(
            table,
            "/tmp/dream_ets_persist_test.ets",
          ))

          // Act - verify data still accessible
          operations.get(table, "important")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("data"))
        |> or_fail_with("Data should persist after save")
      }),
    ]),
    describe("load_from_file", [
      it("loads table from disk", fn() {
        // Arrange - create, save, and DELETE a table first
        let setup = {
          use table <- result.try(helpers.new_string_table("load_test_setup"))
          use _ <- result.try(operations.set(table, "loaded", "value"))
          use _ <- result.try(operations.save_to_file(
            table,
            "/tmp/dream_ets_load_test.ets",
          ))
          // Delete the table so we can load it fresh
          operations.delete_table(table)
        }
        let assert Ok(_) = setup

        // Act
        let result = operations.load_from_file("/tmp/dream_ets_load_test.ets")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should load table from disk")
      }),
    ]),
  ])
}
