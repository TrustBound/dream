//// Example for the doc of `request.convert_metadata` in
//// `dream/servers/mist/request`.

import dream/http/request.{method_to_string}
import dream/servers/mist/request as mist_request
import gleam/bytes_tree
import gleam/http/request as http_request
import gleam/http/response as http_response
import mist.{type Connection, type ResponseData}

pub fn describe(
  request: http_request.Request(Connection),
) -> http_response.Response(ResponseData) {
  // The Dream request has the method, path, query and headers, with an
  // empty body
  let #(dream_request, _request_id) = mist_request.convert_metadata(request)
  // GET /users?page=2 gives "GET /users?page=2"
  let description =
    method_to_string(dream_request.method)
    <> " "
    <> dream_request.path
    <> "?"
    <> dream_request.query
  http_response.new(200)
  |> http_response.set_body(mist.Bytes(bytes_tree.from_string(description)))
}
