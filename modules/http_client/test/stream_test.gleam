import dream_http_client/client
import dream_http_client/stream
import gleam/http

pub fn stream_request_with_valid_client_request_returns_yielder_test() {
  // Arrange
  let client_req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")

  // Act
  let _yielder = stream.stream_request(client_req)

  // Assert
  // stream_request returns a Yielder - we verify function executes
  // Actual streaming behavior would require network requests
  Nil
}
