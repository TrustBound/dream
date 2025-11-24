//// Regression tests for stream_yielder completion behavior
////
//// These tests ensure that stream_yielder correctly handles normal stream
//// completion vs errors. Previously, the yielder would yield
//// `Error("Stream finished")` for normal completion, which was incorrect.
////
//// Correct behavior:
//// - Normal completion: yielder returns Done (no more items)
//// - Actual errors: yielder yields Error(reason) then Done

import dream_http_client/client
import dream_http_client_test
import gleam/http
import gleam/list
import gleam/yielder
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

/// Test that stream_yielder stops cleanly without yielding an error
/// when the stream completes normally
pub fn stream_completes_without_error_test() {
  // Arrange
  let req = mock_request("/stream/fast")

  // Act - consume entire stream
  let results = client.stream_yielder(req) |> yielder.to_list

  // Assert - We got chunks
  { results != [] } |> should.be_true()

  // Assert - ALL results are Ok, no Error("Stream finished") at the end
  let all_ok =
    list.all(results, fn(result) {
      case result {
        Ok(_) -> True
        Error(_) -> False
      }
    })

  all_ok |> should.be_true()
}

/// Test that the last chunk is Ok, not Error("Stream finished")
pub fn last_chunk_is_ok_not_error_test() {
  // Arrange
  let req = mock_request("/stream/fast")

  // Act
  let results = client.stream_yielder(req) |> yielder.to_list

  // Assert - last result is Ok
  case list.last(results) {
    Ok(Ok(_chunk)) -> Nil
    // Correct!
    Ok(Error(_err)) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

/// Test that we can use yielder.to_list() without fear of
/// hanging or getting spurious errors
pub fn to_list_works_correctly_test() {
  // Arrange
  let req = mock_request("/stream/slow")

  // Act - to_list should work without hanging or errors
  let results = client.stream_yielder(req) |> yielder.to_list

  // Assert - We got results
  { results != [] } |> should.be_true()

  // Assert - All results are Ok (no errors)
  let all_ok =
    list.all(results, fn(result) {
      case result {
        Ok(_) -> True
        Error(_) -> False
      }
    })

  all_ok |> should.be_true()
}
