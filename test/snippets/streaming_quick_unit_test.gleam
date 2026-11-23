//// Streaming quick reference: Testing Streaming
////
//// A dream_test unit test for a streaming response, as shown in
//// docs/guides/streaming-quick-reference.md. The streaming snippet tests run it.

import dream/http/response.{Stream, stream_response}
import dream/http/status
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/yielder

pub fn tests() -> TestSuite {
  describe("streaming", [
    it("yields expected chunks", fn() {
      // Arrange
      let stream =
        yielder.range(1, 3)
        |> yielder.map(int_to_byte)

      // Act
      let response =
        stream_response(status.ok, stream, "application/octet-stream")

      // Assert
      case response.body {
        Stream(chunks) ->
          yielder.to_list(chunks)
          |> list.length()
          |> should()
          |> be_equal(3)
          |> or_fail_with("Should have 3 chunks")
        _ -> Ok(fail_with("Expected Stream body"))
      }
    }),
  ])
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
}
