//// Tests for dream_ets/config module.

import dream_ets/config
import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import matchers/extract_table_name.{extract_table_name}

pub fn tests() -> UnitTest {
  describe("config", [
    describe("new", [
      it("creates table successfully", fn() {
        // Arrange
        let config_value = config.new("test_new_creates")

        // Act
        let result =
          config_value
          |> config.key_string()
          |> config.value_string()
          |> config.create()

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table")
      }),
      it("stores correct table name", fn() {
        // Arrange
        let config_value = config.new("test_table_name_check")

        // Act
        let result =
          config_value
          |> config.key_string()
          |> config.value_string()
          |> config.create()

        // Assert
        result
        |> should()
        |> extract_table_name()
        |> equal("test_table_name_check")
        |> or_fail_with("Should have correct name")
      }),
    ]),
    describe("table_type", [
      it("creates table with set type", fn() {
        // Arrange
        let set_config =
          config.new("test_set_type")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_set())

        // Act
        let result = config.create(set_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with set type")
      }),
      it("creates table with ordered_set type", fn() {
        // Arrange
        let ordered_config =
          config.new("test_ordered_type")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result = config.create(ordered_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with ordered_set type")
      }),
      it("creates table with bag type", fn() {
        // Arrange
        let bag_config =
          config.new("test_bag_type")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_bag())

        // Act
        let result = config.create(bag_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with bag type")
      }),
      it("creates table with duplicate_bag type", fn() {
        // Arrange
        let dup_bag_config =
          config.new("test_dup_bag_type")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_duplicate_bag())

        // Act
        let result = config.create(dup_bag_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with duplicate_bag type")
      }),
    ]),
    describe("keypos", [
      it("creates table with custom key position", fn() {
        // Arrange
        let keypos_config =
          config.new("test_keypos")
          |> config.keypos(2)
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(keypos_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with custom keypos")
      }),
    ]),
    describe("access", [
      it("creates table with protected access", fn() {
        // Arrange
        let protected_config =
          config.new("test_protected")
          |> config.key_string()
          |> config.value_string()
          |> config.access(config.access_protected())

        // Act
        let result = config.create(protected_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with protected access")
      }),
    ]),
    describe("read_concurrency", [
      it("creates table with read concurrency enabled", fn() {
        // Arrange
        let concurrency_config =
          config.new("test_read_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)

        // Act
        let result = config.create(concurrency_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with read concurrency")
      }),
    ]),
    describe("write_concurrency", [
      it("creates table with write concurrency enabled", fn() {
        // Arrange
        let concurrency_config =
          config.new("test_write_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.write_concurrency(True)

        // Act
        let result = config.create(concurrency_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with write concurrency")
      }),
    ]),
    describe("compressed", [
      it("creates table with compression enabled", fn() {
        // Arrange
        let compressed_config =
          config.new("test_compressed")
          |> config.key_string()
          |> config.value_string()
          |> config.compressed(True)

        // Act
        let result = config.create(compressed_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with compression")
      }),
    ]),
    describe("key_string", [
      it("creates table with string key encoding", fn() {
        // Arrange
        let string_key_config =
          config.new("test_key_string")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(string_key_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with string keys")
      }),
    ]),
    describe("value_string", [
      it("creates table with string value encoding", fn() {
        // Arrange
        let string_value_config =
          config.new("test_value_string")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(string_value_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create table with string values")
      }),
    ]),
    describe("counter", [
      it("creates counter table", fn() {
        // Arrange
        let counter_config =
          config.new("test_counter")
          |> config.counter()

        // Act
        let result = config.create(counter_config)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should create counter table")
      }),
    ]),
    describe("create", [
      it("returns InvalidKey error for missing key encoder", fn() {
        // Arrange - config without encoders
        let incomplete_config = config.new("test_incomplete")

        // Act
        let result = config.create(incomplete_config)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should return error for missing key encoder")
      }),
      it("returns TableAlreadyExists error for duplicate name", fn() {
        // Arrange
        let config1 =
          config.new("duplicate_test")
          |> config.key_string()
          |> config.value_string()

        let _table1 = config.create(config1)

        let config2 =
          config.new("duplicate_test")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(config2)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should return error for duplicate table name")
      }),
    ]),
  ])
}
