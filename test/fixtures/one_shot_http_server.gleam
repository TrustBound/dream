//// One-shot local HTTP server that records the request it receives.
////
//// Each `start` opens a new socket on 127.0.0.1 with a port chosen by the
//// operating system, so tests never share a port. The server accepts one
//// connection, answers with the given status and body, and stops.

import gleam/int

pub type OneShotServer

/// The request as it arrived on the wire. Header names are lowercase.
pub type CapturedRequest {
  CapturedRequest(
    method: String,
    target: String,
    headers: List(#(String, String)),
    body: String,
  )
}

/// Starts a server that answers with `status` and `body`
/// (content-type: application/json).
@external(erlang, "one_shot_http_server_ffi", "start")
pub fn start(status: Int, body: String) -> OneShotServer

@external(erlang, "one_shot_http_server_ffi", "port")
pub fn port(server: OneShotServer) -> Int

/// Waits up to 3 seconds for the request that the server received.
@external(erlang, "one_shot_http_server_ffi", "await_request")
pub fn await_request(server: OneShotServer) -> Result(CapturedRequest, Nil)

/// `http://127.0.0.1:<port>` for this server.
pub fn base_url(server: OneShotServer) -> String {
  "http://127.0.0.1:" <> int.to_string(port(server))
}

/// Method and request target, for example `#("PUT", "/logs/_doc/1")`.
pub fn request_line(request: CapturedRequest) -> #(String, String) {
  #(request.method, request.target)
}

/// The body of the captured request.
pub fn request_body(request: CapturedRequest) -> String {
  request.body
}
