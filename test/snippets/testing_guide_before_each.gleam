import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, after_each, before_each, describe, it}
import gleam/string

pub fn tests() -> UnitTest {
  describe("record tests", [
    before_each(fn() {
      // Reset test state
      AssertionOk
    }),
    after_each(fn() {
      // Cleanup
      AssertionOk
    }),
    it("creates record", fn() {
      create_record("Alice")
      |> should()
      |> be_ok()
      |> or_fail_with("Should create record")
    }),
    it("updates record", fn() {
      update_record("Alice", "Alicia")
      |> should()
      |> equal(Ok("Alicia"))
      |> or_fail_with("Should update record")
    }),
  ])
}

pub fn create_record(name: String) -> Result(String, String) {
  case string.is_empty(name) {
    True -> Error("Name is required")
    False -> Ok(name)
  }
}

pub fn update_record(
  _old_name: String,
  new_name: String,
) -> Result(String, String) {
  create_record(new_name)
}
