//// README: Error Handling
////
//// Sends a request with a 5 second timeout and handles each kind of error.

import dream_http_client/client.{
  HttpResponse, RequestError, ResponseError, host, path, port, scheme, send,
  timeout, transport_error_to_string,
}
import gleam/http
import gleam/int
import gleam/io

pub fn fetch_text_with_timeout() -> Result(String, String) {
  let request =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> timeout(5000)

  case send(request) {
    Ok(HttpResponse(body: body, ..)) -> {
      io.println(body)
      Ok(body)
    }
    Error(ResponseError(response: response)) -> {
      io.println_error("HTTP error " <> int.to_string(response.status))
      Error(response.body)
    }
    Error(RequestError(error: error)) -> {
      let message = transport_error_to_string(error)
      io.println_error("Request failed: " <> message)
      Error(message)
    }
  }
}
