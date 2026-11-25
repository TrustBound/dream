//// Requests to the app, sent through its router as the server sends
//// them, and the text of a response.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{Get, Http, Http1, Request}
import dream/http/response.{type Response, Bytes, Stream, Text}
import gleam/bit_array
import gleam/option
import gleam/yielder
import router
import services.{type Services}

/// Sends `GET path` through the routes of the app, with `services`, and
/// gives the status and the whole body. A streamed body is read to its
/// end.
pub fn get(services: Services, path: String) -> #(Int, String) {
  let response =
    dream.route_request(
      router.create_router(),
      get_request(path),
      EmptyContext,
      services,
    )
  #(response.status, body_text(response))
}

fn body_text(response: Response) -> String {
  case response.body {
    Text(text) -> text
    Bytes(bytes) -> bytes_text(bytes)
    Stream(chunks) ->
      chunks |> yielder.to_list |> bit_array.concat |> bytes_text
  }
}

fn bytes_text(bytes: BitArray) -> String {
  case bit_array.to_string(bytes) {
    Ok(text) -> text
    Error(Nil) -> "(the body is not UTF-8 text)"
  }
}

fn get_request(path: String) -> request.Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path:,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}
