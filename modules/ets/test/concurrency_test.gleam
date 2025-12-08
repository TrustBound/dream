//// Tests for concurrency options in dream_ets.

import dream_ets/config
import dream_test/assertions/should.{be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("concurrency", [
    describe("read_concurrency", [
      it("creates table with read concurrency enabled", fn() {
        // Arrange & Act
        let result =
          config.new("test_read_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)
          |> config.create()

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with read concurrency")
      }),
    ]),
    describe("write_concurrency", [
      it("creates table with write concurrency enabled", fn() {
        // Arrange & Act
        let result =
          config.new("test_write_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.write_concurrency(True)
          |> config.create()

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with write concurrency")
      }),
    ]),
    describe("both concurrency options", [
      it("creates table with both concurrency options enabled", fn() {
        // Arrange & Act
        let result =
          config.new("test_both_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)
          |> config.write_concurrency(True)
          |> config.create()

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with both concurrency options")
      }),
    ]),
  ])
}
