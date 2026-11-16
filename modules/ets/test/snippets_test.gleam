//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// Each snippet is in test/snippets/ and the README shows the same code.
//// Each test checks the exact result of one snippet.

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import snippets/advanced_operations
import snippets/basic_operations
import snippets/counter_tables
import snippets/creating_tables
import snippets/custom_types
import snippets/distributed_locks
import snippets/doc_insert_new_race
import snippets/doc_member
import snippets/error_handling
import snippets/insert_new
import snippets/page_view_analytics
import snippets/session_cache
import snippets/table_configuration
import snippets/table_persistence
import snippets/type_safe_operations
import snippets/work_queue

pub fn tests() -> UnitTest {
  describe("snippets", [
    it("creating tables returns the stored name", fn() {
      creating_tables.create_string_table()
      |> should()
      |> equal(Ok("Alice"))
      |> or_fail_with("Should return the stored name")
    }),
    it("basic operations returns the stored greeting", fn() {
      basic_operations.store_and_retrieve()
      |> should()
      |> equal(Ok("Hello, World!"))
      |> or_fail_with("Should return the stored greeting")
    }),
    it("counter tables counts three page views", fn() {
      counter_tables.increment_page_views()
      |> should()
      |> equal(Ok(3))
      |> or_fail_with("Counter should equal 3")
    }),
    it("table configuration returns the stored value", fn() {
      table_configuration.configure_table()
      |> should()
      |> equal(Ok("value"))
      |> or_fail_with("Should return the stored value")
    }),
    it("type safe operations returns the stored value", fn() {
      type_safe_operations.type_safe_storage()
      |> should()
      |> equal(Ok("value"))
      |> or_fail_with("Should return the stored value")
    }),
    it("atomic take returns the job", fn() {
      advanced_operations.atomic_take()
      |> should()
      |> equal(Ok("send_email"))
      |> or_fail_with("Should return the taken job")
    }),
    it("table persistence keeps the data after a save", fn() {
      table_persistence.save_to_disk()
      |> should()
      |> equal(Ok("important data"))
      |> or_fail_with("Should return the saved data")
    }),
    it("custom types returns the stored user", fn() {
      custom_types.store_custom_type()
      |> should()
      |> equal(Ok("Alice <alice@example.com>"))
      |> or_fail_with("Should return the stored user")
    }),
    it("insert new registers a new user", fn() {
      insert_new.register_user()
      |> should()
      |> equal(Ok(True))
      |> or_fail_with("Should register the user")
    }),
    it("error handling describes a found and a missing user", fn() {
      error_handling.describe_two_lookups()
      |> should()
      |> equal(Ok(["Found Alice", "No user for user:456"]))
      |> or_fail_with("Should describe each lookup result")
    }),
    it("error handling describes a lookup on a deleted table", fn() {
      error_handling.describe_lookup_after_delete()
      |> should()
      |> equal(Ok("The table was deleted"))
      |> or_fail_with("Should take the TableNotFound branch")
    }),
    it("member doc describes each member result", fn() {
      doc_member.describe_users_before_and_after_delete()
      |> should()
      |> equal(
        Ok([
          "user:123 exists",
          "user:456 does not exist",
          "The table was deleted",
        ]),
      )
      |> or_fail_with("Should describe each member result")
    }),
    it("insert_new doc inserts once each way", fn() {
      doc_insert_new_race.insert_twice_each_way()
      |> should()
      |> equal(Ok([True, False, True, False]))
      |> or_fail_with("Should insert only the first time")
    }),
    it("session cache returns the stored user", fn() {
      session_cache.store_session()
      |> should()
      |> equal(Ok(option.Some("user:alice")))
      |> or_fail_with("Should return the session's user")
    }),
    it("page view analytics counts one view", fn() {
      page_view_analytics.count_homepage_view()
      |> should()
      |> equal(Ok(1))
      |> or_fail_with("Should count one view")
    }),
    it("distributed locks gives the lock to the first owner only", fn() {
      distributed_locks.acquire_lock_twice()
      |> should()
      |> equal(Ok(#(Ok("Lock acquired"), Error("Resource already locked"))))
      |> or_fail_with("Second attempt should find the lock taken")
    }),
    it("work queue gives the job to the first claim only", fn() {
      work_queue.claim_next_job_twice()
      |> should()
      |> equal(Ok(#("Claimed send_email", "No jobs waiting")))
      |> or_fail_with("Second claim should find no job")
    }),
  ])
}
