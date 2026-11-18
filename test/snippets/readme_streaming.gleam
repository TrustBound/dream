//// README: Streaming responses
////
//// A controller that streams a log as chunks, as shown in the root README.

import dream/http.{ok, stream_response}
import gleam/bit_array
import gleam/yielder

pub type Services {
  Services(log_store: List(String))
}

pub fn download_log(_request, _context, services: Services) {
  let stream = make_log_stream(services.log_store)
  stream_response(ok, stream, "text/plain")
}

fn make_log_stream(lines: List(String)) -> yielder.Yielder(BitArray) {
  yielder.from_list(lines)
  |> yielder.map(fn(line) { bit_array.from_string(line <> "\n") })
}
