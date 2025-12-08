//// Tests for type safety in dream_ets.

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/option
import gleam/result

pub fn tests() -> UnitTest {
  describe("type_safety", [
    describe("string key type", [
      it("enforces string key type", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_string_key_type")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          operations.set(table, "string_key", "value")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should set string key")
      }),
    ]),
    describe("int value type", [
      it("enforces int value type", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_int_value_type")
            |> config.key_string()
            |> config.value(encoders.int_encoder, encoders.int_decoder())
            |> config.create(),
          )
          operations.set(table, "key1", 42)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should set int value")
      }),
      it("stores and retrieves int values", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_int_value_get")
            |> config.key_string()
            |> config.value(encoders.int_encoder, encoders.int_decoder())
            |> config.create(),
          )
          let _ = operations.set(table, "key1", 42)
          operations.get(table, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some(42))
        |> or_fail_with("Should get int value")
      }),
    ]),
    describe("counter table types", [
      it("enforces string int types", fn() {
        // Arrange
        let result = {
          use counter <- result.try(
            config.new("test_counter_types")
            |> config.counter()
            |> config.create(),
          )
          operations.set(counter, "count1", 100)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should set counter value")
      }),
      it("retrieves counter values", fn() {
        // Arrange
        let result = {
          use counter <- result.try(
            config.new("test_counter_get")
            |> config.counter()
            |> config.create(),
          )
          let _ = operations.set(counter, "count1", 100)
          operations.get(counter, "count1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some(100))
        |> or_fail_with("Should get counter value")
      }),
    ]),
    describe("keys returns typed list", [
      it("returns typed key list with correct length", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_typed_keys")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          use all_keys <- result.try(operations.keys(table))
          Ok(list.length(all_keys))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(2)
        |> or_fail_with("Should return typed keys")
      }),
    ]),
    describe("values returns typed list", [
      it("returns typed value list with correct length", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_typed_values")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          let _ = operations.set(table, "key2", "value2")
          use all_values <- result.try(operations.values(table))
          Ok(list.length(all_values))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(2)
        |> or_fail_with("Should return typed values")
      }),
    ]),
    describe("to_list returns typed pairs", [
      it("returns typed pairs", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("test_typed_pairs")
            |> config.key_string()
            |> config.value_string()
            |> config.create(),
          )
          let _ = operations.set(table, "key1", "value1")
          operations.to_list(table)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal([#("key1", "value1")])
        |> or_fail_with("Should return typed pairs")
      }),
    ]),
  ])
}
