//// Tests for encoder/decoder functions

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import gleam/result

pub fn tests() -> UnitTest {
  describe("encoders", [
    describe("bool encoding", [
      it("stores and retrieves bool values", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("bool_test")
            |> config.key_string()
            |> config.value(encoders.bool_encoder, encoders.bool_decoder())
            |> config.create(),
          )
          use _ <- result.try(operations.set(table, "flag1", True))
          use _ <- result.try(operations.set(table, "flag2", False))
          use val1 <- result.try(operations.get(table, "flag1"))
          use val2 <- result.try(operations.get(table, "flag2"))
          Ok(#(val1, val2))
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(#(option.Some(True), option.Some(False)))
        |> or_fail_with("Should store and retrieve bool values")
      }),
    ]),
    describe("float encoding", [
      it("stores and retrieves float values", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("float_test")
            |> config.key_string()
            |> config.value(encoders.float_encoder, encoders.float_decoder())
            |> config.create(),
          )
          use _ <- result.try(operations.set(table, "pi", 3.14159))
          operations.get(table, "pi")
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some(3.14159))
        |> or_fail_with("Should store and retrieve float values")
      }),
    ]),
    describe("custom key encoding", [
      it("uses custom key encoder and decoder", fn() {
        // Arrange
        let result = {
          use table <- result.try(
            config.new("custom_key_test")
            |> config.key(encoders.int_encoder, encoders.int_decoder())
            |> config.value_string()
            |> config.create(),
          )
          use _ <- result.try(operations.set(table, 123, "value"))
          operations.get(table, 123)
        }

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(option.Some("value"))
        |> or_fail_with("Should use custom key encoder")
      }),
    ]),
  ])
}
