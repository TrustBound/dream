import dream/utilities/http/client as client
import dream/utilities/http/client/fetch as fetch
import gleam/bytes_tree
import gleam/http
import gleam/yielder
import gleeunit/should
import mockth

pub fn request_with_valid_client_request_returns_result_test() {
  use _mock <- mockth.with_mock(
    module: "dream@utilities@http@client@stream",
    function: "stream_request",
    replacement: fn(_req) {
      // Return a mock yielder that produces a single chunk
      let mock_chunk = bytes_tree.from_string("Mock response body")
      yielder.from_list([mock_chunk])
    },
  )

  // Arrange
  let client_req = client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
  
  // Act
  let result = fetch.request(client_req)
  
  // Assert
  // Verify the function returns the mocked response
  case result {
    Ok(body) -> body |> should.equal("Mock response body")
    Error(_) -> panic as "Expected Ok but got Error"
  }
}

