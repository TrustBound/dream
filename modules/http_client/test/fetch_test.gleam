import dream_http_client/client
import dream_http_client/fetch
import gleam/bytes_tree
import gleam/http
import gleam/yielder
import gleeunit/should
import mockth

pub fn request_with_valid_client_request_returns_result_test() {
  use _mock <- mockth.with_mock(
    module: "dream_http_client@stream",
    function: "stream_request",
    replacement: fn(_req) {
      let mock_chunk = bytes_tree.from_string("Mock response body")
      yielder.from_list([mock_chunk])
    },
  )

  let client_req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")

  let result = fetch.request(client_req)

  case result {
    Ok(body) -> body |> should.equal("Mock response body")
    Error(_) -> panic as "Expected Ok but got Error"
  }
}
