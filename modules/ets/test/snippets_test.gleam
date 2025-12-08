//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// Each snippet is in test/snippets/ and has a run() function that returns
//// Result. If any snippet fails, the test fails with the error.

import dream_test/assertions/should.{be_ok, be_true, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/advanced_operations
import snippets/basic_operations
import snippets/counter_tables
import snippets/creating_tables
import snippets/custom_types
import snippets/insert_new
import snippets/table_configuration
import snippets/table_persistence
import snippets/type_safe_operations

pub fn tests() -> UnitTest {
  describe("snippets", [
    it("creating tables", fn() {
      creating_tables.create_string_table()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed to create table")
    }),
    it("basic operations", fn() {
      basic_operations.store_and_retrieve()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed basic operations")
    }),
    it("counter tables", fn() {
      counter_tables.increment_page_views()
      |> should()
      |> be_ok()
      |> equal(3)
      |> or_fail_with("Counter should equal 3")
    }),
    it("table configuration", fn() {
      table_configuration.configure_table()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed table configuration")
    }),
    it("type safe operations", fn() {
      type_safe_operations.type_safe_storage()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed type-safe operations")
    }),
    it("advanced operations", fn() {
      advanced_operations.atomic_take()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed advanced operation")
    }),
    it("table persistence", fn() {
      table_persistence.save_to_disk()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed persistence")
    }),
    it("custom types", fn() {
      custom_types.store_custom_type()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed custom type storage")
    }),
    it("insert new", fn() {
      insert_new.register_user()
      |> should()
      |> be_ok()
      |> be_true()
      |> or_fail_with("Failed to register user")
    }),
  ])
}
