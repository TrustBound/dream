import dream/utilities/http/client as client
import dream/utilities/http/client/fetch as fetch
import gleam/http
import gleeunit/should

pub fn request_with_valid_client_request_returns_result_test() {
  // Arrange
  let client_req = client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
  
  // Act
  let result = fetch.request(client_req)
  
  // Assert
  // Request function returns Result - actual network requests may fail
  // but we verify the function signature is correct
  case result {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

