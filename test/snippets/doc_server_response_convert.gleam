//// Doc comment examples: dream/servers/mist/response.convert

import dream/http/response.{type Response}
import dream/servers/mist/response.{convert} as _
import gleam/http/request as http_request
import gleam/http/response as http_response
import mist.{type Connection, type ResponseData}

pub fn send_user(
  mist_request: http_request.Request(Connection),
  user_json: String,
) -> http_response.Response(ResponseData) {
  // Internal use - normally called by the request handler
  let dream_response = response.json_response(200, user_json)
  let mist_response = convert(mist_request, dream_response)
  // Mist server sends mist_response to client
  mist_response
}

pub fn send_stream(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
) -> http_response.Response(ResponseData) {
  // A Stream body is sent with chunked transfer encoding
  convert(mist_request, dream_response)
}
