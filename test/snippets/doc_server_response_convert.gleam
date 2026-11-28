//// Doc comment examples: dream/servers/mist/response.convert and
//// convert_stream

import dream/http/response.{type Response}
import dream/servers/mist/response.{convert, convert_stream} as _
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/yielder
import mist.{type Connection, type ResponseData}

pub fn send_user(user_json: String) -> http_response.Response(ResponseData) {
  // Internal use - normally called by the request handler
  let dream_response = response.json_response(200, user_json)
  let mist_response = convert(dream_response)
  // Mist server sends mist_response to client
  mist_response
}

pub fn send_stream(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
  stream: yielder.Yielder(BitArray),
) -> http_response.Response(ResponseData) {
  // Internal use - called by the handler when body is Stream
  let mist_response = convert_stream(mist_request, dream_response, stream)
  mist_response
}
