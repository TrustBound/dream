//// Streaming guide: Unit Tests
////
//// A dream_test unit test for a streaming response, as shown in
//// docs/guides/streaming.md. The streaming snippet tests run it.

import dream/http/response.{Stream, stream_response}
import dream/http/status
import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/yielder

pub fn tests() -> UnitTest {
  describe("streaming", [
    it("generates expected chunks", fn() {
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
          |> equal(3)
          |> or_fail_with("Should have 3 chunks")
        _ -> fail_with("Expected Stream body")
      }
    }),
  ])
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
}
