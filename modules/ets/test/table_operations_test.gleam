//// Tests for dream_ets/operations module.

import dream_ets/config
import dream_ets/operations
import dream_test/assertions/should.{
  be_false, be_ok, be_true, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn tests() -> UnitTest {
  describe("table_operations", [
    describe("set", [
      it("stores value with valid key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_set_valid")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.set(table, "key1", "value1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should set value")
      }),
      it("updates value with existing key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_set_update")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "original")
          let _ = operations.set(table, "key1", "updated")
          operations.get(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("updated"))
        |> or_fail_with("Should update value")
      }),
    ]),
    describe("get", [
      it("returns value for existing key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_get_existing")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          operations.get(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("value1"))
        |> or_fail_with("Should get correct value")
      }),
      it("returns None for non-existent key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_get_nonexistent")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.get(table, "nonexistent_key")
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
      it("removes existing key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_delete_existing")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.delete(table, "key1")
          operations.get(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.None)
        |> or_fail_with("Key should be deleted")
      }),
    ]),
    describe("member", [
      it("returns true for existing key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_member_exists")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          Ok(operations.member(table, "key1"))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> be_true()
        |> or_fail_with("Should find existing key")
      }),
      it("returns false for non-existent key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_member_nonexistent")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          Ok(operations.member(table, "nonexistent_key"))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> be_false()
        |> or_fail_with("Should not find non-existent key")
      }),
    ]),
    describe("keys", [
      it("returns all keys", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_keys")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          let _ = operations.set(table, "key3", "value3")
          use all_keys <- result.try(operations.keys(table))
          Ok(list.sort(all_keys, string.compare))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(["key1", "key2", "key3"])
        |> or_fail_with("Should return all keys")
      }),
    ]),
    describe("values", [
      it("returns all values", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_values")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          use all_values <- result.try(operations.values(table))
          Ok(list.sort(all_values, string.compare))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(["value1", "value2"])
        |> or_fail_with("Should return all values")
      }),
    ]),
    describe("to_list", [
      it("returns all pairs", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_to_list")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          use pairs <- result.try(operations.to_list(table))
          Ok(list.sort(pairs, fn(a, b) { string.compare(a.0, b.0) }))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal([#("key1", "value1"), #("key2", "value2")])
        |> or_fail_with("Should return all pairs")
      }),
    ]),
    describe("size", [
      it("returns number of objects", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_size")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          let _ = operations.set(table, "key3", "value3")
          operations.size(table)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(3)
        |> or_fail_with("Should return correct size")
      }),
    ]),
    describe("insert_new", [
      it("inserts and returns true for non-existent key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_insert_new_success")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.insert_new(table, "key1", "value1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> be_true()
        |> or_fail_with("Should insert new key")
      }),
      it("returns false for existing key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_insert_new_fail")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "original")
          operations.insert_new(table, "key1", "new_value")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> be_false()
        |> or_fail_with("Should not insert existing key")
      }),
    ]),
    describe("take", [
      it("returns value and deletes key", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_take_existing")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          operations.take(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("value1"))
        |> or_fail_with("Should get value")
      }),
      it("deletes key after take", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_take_deletes")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.take(table, "key1")
          operations.get(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.None)
        |> or_fail_with("Key should be deleted")
      }),
    ]),
    describe("delete_all_objects", [
      it("clears table", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_delete_all")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          let _ = operations.set(table, "key3", "value3")
          let _ = operations.delete_all_objects(table)
          operations.size(table)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(0)
        |> or_fail_with("Should have size 0")
      }),
    ]),
    describe("delete_table", [
      it("removes entire table", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_delete_table")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          operations.delete_table(table)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should delete table")
      }),
    ]),
  ])
}
