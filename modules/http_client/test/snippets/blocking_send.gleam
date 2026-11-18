//// README: Blocking - send()
////
//// Sends a request and turns each kind of error into a message.

import dream_http_client/client.{
  HttpResponse, RequestError, ResponseError, host, path, port, scheme, send,
  transport_error_to_string,
}
import gleam/http

pub fn fetch_text() -> Result(String, String) {
  let result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> send()

  case result {
    Ok(HttpResponse(body: body, ..)) -> Ok(body)
    Error(ResponseError(response: response)) -> Error(response.body)
    Error(RequestError(error: error)) -> Error(transport_error_to_string(error))
  }
}
