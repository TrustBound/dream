//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// Each snippet is in test/snippets/ and has a run() function that returns
//// Result. If any snippet fails, the test fails with the error.

import dream_test/assertions/should.{be_ok, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import snippets/sse_action_builders
import snippets/sse_event_builders

pub fn tests() -> UnitTest {
  describe("snippets", [
    it("sse event builders", fn() {
      sse_event_builders.build_event()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed SSE event builder snippet")
    }),
    it("sse action builders", fn() {
      sse_action_builders.build_actions()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed SSE action builder snippet")
    }),
  ])
}
