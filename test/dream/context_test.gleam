//// Tests for dream/context module.

import dream/context
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

pub fn tests() -> UnitTest {
  describe("context", [
    describe("new_context", [
      it("creates AppContext with provided request id", fn() {
        let request_id = "test-request-123"

        let app_context = context.new_context(request_id)

        extract_request_id(app_context)
        |> should()
        |> equal(request_id)
        |> or_fail_with("AppContext should contain the request id")
      }),
      it("creates AppContext with empty string when given empty id", fn() {
        let app_context = context.new_context("")

        extract_request_id(app_context)
        |> should()
        |> equal("")
        |> or_fail_with("AppContext should contain empty string")
      }),
    ]),
  ])
}

fn extract_request_id(app_context: context.AppContext) -> String {
  let context.AppContext(id) = app_context
  id
}
