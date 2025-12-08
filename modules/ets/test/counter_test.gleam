//// Tests for dream_ets/helpers module (counter functions).

import dream_ets/helpers
import dream_ets/operations
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/result

pub fn tests() -> UnitTest {
  describe("counter", [
    describe("new_counter", [
      it("creates counter table", fn() {
        // Arrange & Act
        let result = helpers.new_counter("test_counter_create")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create counter table")
      }),
    ]),
    describe("increment", [
      it("returns Ok result for new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("test_increment_new_ok"))
          helpers.increment(counter, "new_key")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should increment")
      }),
      it("returns one for new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter(
            "test_increment_returns_one",
          ))
          helpers.increment(counter, "new_key")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(1)
        |> or_fail_with("Should initialize to 1")
      }),
      it("increments existing key value", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter(
            "test_increment_existing",
          ))
          let _ = operations.set(counter, "key1", 5)
          helpers.increment(counter, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(6)
        |> or_fail_with("Should increment to 6")
      }),
    ]),
    describe("increment_by", [
      it("adds amount to existing value", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("test_increment_by"))
          let _ = operations.set(counter, "key1", 10)
          helpers.increment_by(counter, "key1", 5)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(15)
        |> or_fail_with("Should increment to 15")
      }),
    ]),
    describe("decrement", [
      it("decrements existing key value", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter(
            "test_decrement_existing",
          ))
          let _ = operations.set(counter, "key1", 10)
          helpers.decrement(counter, "key1")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(9)
        |> or_fail_with("Should decrement to 9")
      }),
    ]),
    describe("decrement_by", [
      it("subtracts amount from existing value", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("test_decrement_by"))
          let _ = operations.set(counter, "key1", 20)
          helpers.decrement_by(counter, "key1", 7)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(13)
        |> or_fail_with("Should decrement to 13")
      }),
    ]),
  ])
}
