//// Tests for operations on a table that was deleted.
////
//// Each operation must return `Error(TableNotFound)` and must not crash the
//// calling process.

import dream_ets/helpers
import dream_ets/internal
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table, TableNotFound}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/result

fn deleted_string_table(
  name: String,
) -> Result(Table(String, String), EtsError) {
  use created <- result.try(helpers.new_string_table(name))
  use _ <- result.try(operations.delete_table(created))
  Ok(created)
}

fn deleted_counter(name: String) -> Result(Table(String, Int), EtsError) {
  use created <- result.try(helpers.new_counter(name))
  use _ <- result.try(operations.delete_table(created))
  Ok(created)
}

pub fn tests() -> UnitTest {
  describe("deleted table", [
    it("get returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_get"))

        // Act
        operations.get(deleted, "key")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("get on a deleted table should return TableNotFound")
    }),
    it("set returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_set"))

        // Act
        operations.set(deleted, "key", "value")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("set on a deleted table should return TableNotFound")
    }),
    it("delete returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_delete"))

        // Act
        operations.delete(deleted, "key")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("delete on a deleted table should return TableNotFound")
    }),
    it("delete_table returns TableNotFound the second time", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_delete_table"))

        // Act
        operations.delete_table(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "delete_table on a deleted table should return TableNotFound",
      )
    }),
    it("size returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_size"))

        // Act
        operations.size(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("size on a deleted table should return TableNotFound")
    }),
    it("keys returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_keys"))

        // Act
        operations.keys(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("keys on a deleted table should return TableNotFound")
    }),
    it("values returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_values"))

        // Act
        operations.values(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("values on a deleted table should return TableNotFound")
    }),
    it("to_list returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_to_list"))

        // Act
        operations.to_list(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("to_list on a deleted table should return TableNotFound")
    }),
    it("insert_new returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_insert_new"))

        // Act
        operations.insert_new(deleted, "key", "value")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "insert_new on a deleted table should return TableNotFound",
      )
    }),
    it("take returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_take"))

        // Act
        operations.take(deleted, "key")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("take on a deleted table should return TableNotFound")
    }),
    it("update_element returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_update"))

        // Act
        operations.update_element(
          deleted,
          "key",
          2,
          internal.to_dynamic("value"),
        )
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "update_element on a deleted table should return TableNotFound",
      )
    }),
    it("delete_all_objects returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_delete_all"))

        // Act
        operations.delete_all_objects(deleted)
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "delete_all_objects on a deleted table should return TableNotFound",
      )
    }),
    it("save_to_file returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_save"))

        // Act
        operations.save_to_file(deleted, "/tmp/dream_ets_deleted_table.ets")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "save_to_file on a deleted table should return TableNotFound",
      )
    }),
    it("increment returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_counter("deleted_increment"))

        // Act
        helpers.increment(deleted, "hits")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "increment on a deleted table should return TableNotFound",
      )
    }),
    it("decrement returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_counter("deleted_decrement"))

        // Act
        helpers.decrement(deleted, "hits")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "decrement on a deleted table should return TableNotFound",
      )
    }),
    it("member returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_member"))

        // Act
        operations.member(deleted, "key")
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("member on a deleted table should return TableNotFound")
    }),
    it("match returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_match"))

        // Act
        operations.match(deleted, internal.to_dynamic(#("$1", "$2")))
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("match on a deleted table should return TableNotFound")
    }),
    it("match_object returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_match_object"))

        // Act
        operations.match_object(deleted, internal.to_dynamic(#("$1", "$2")))
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with(
        "match_object on a deleted table should return TableNotFound",
      )
    }),
    it("select returns TableNotFound", fn() {
      // Arrange
      let result = {
        use deleted <- result.try(deleted_string_table("deleted_select"))

        // Act
        operations.select(
          deleted,
          internal.to_dynamic([#(#("$1", "$2"), [], ["$_"])]),
        )
      }

      // Assert
      result
      |> should()
      |> equal(Error(TableNotFound))
      |> or_fail_with("select on a deleted table should return TableNotFound")
    }),
  ])
}
