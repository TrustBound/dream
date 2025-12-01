//// Tests for dream/context module.

import dream/context
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import matchers/extract_request_id.{extract_request_id}

pub fn tests() -> UnitTest {
  describe("context", [
    describe("new_context", [
      it("creates AppContext with provided request id", fn() {
        // Arrange
        let request_id = "test-request-123"

        // Act
        let result = context.new_context(request_id)

        // Assert
        result
        |> should()
        |> extract_request_id()
        |> equal(request_id)
        |> or_fail_with("AppContext should contain the request id")
      }),
      it("creates AppContext with empty string when given empty id", fn() {
        // Arrange
        let request_id = ""

        // Act
        let result = context.new_context(request_id)

        // Assert
        result
        |> should()
        |> extract_request_id()
        |> equal("")
        |> or_fail_with("AppContext should contain empty string")
      }),
    ]),
  ])
}
