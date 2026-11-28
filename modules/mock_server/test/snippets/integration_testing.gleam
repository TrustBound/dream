//// README: Integration Testing
////
//// A test that runs against the mock server on a free port.

import dream_mock_server/server
import gleam/int
import gleeunit/should
import snippets/http_helper
import snippets/port

pub fn fast_stream_sends_ten_chunks_test() {
  let port = port.free_port()
  let mock = server.start(port) |> should.be_ok()

  // Send the request to http://localhost:<port>
  let response =
    http_helper.get(
      "http://localhost:" <> int.to_string(port) <> "/stream/fast",
    )

  server.stop(mock)
  response
  |> should.equal(
    Ok(#(
      200,
      "Chunk 1\nChunk 2\nChunk 3\nChunk 4\nChunk 5\nChunk 6\nChunk 7\nChunk 8\nChunk 9\nChunk 10\n",
    )),
  )
}
