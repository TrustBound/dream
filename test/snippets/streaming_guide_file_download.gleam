//// Streaming guide: Large File Streaming
////
//// A controller that sends a file from disk in 64 KB chunks, as shown in
//// docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, empty_response, stream_response}
import dream/http/status
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(file_path: String)
}

pub fn download_file(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  simplifile.read_bits(services.file_path)
  |> result.map(create_file_stream)
  |> result.map(create_binary_stream_response)
  |> result.unwrap(empty_response(status.not_found))
}

fn create_file_stream(file_data: BitArray) -> yielder.Yielder(BitArray) {
  yielder.unfold(file_data, take_next_chunk)
}

fn take_next_chunk(remaining: BitArray) -> yielder.Step(BitArray, BitArray) {
  case remaining {
    <<>> -> yielder.Done
    <<chunk:bytes-size(65_536), rest:bytes>> -> yielder.Next(chunk, rest)
    last_chunk -> yielder.Next(last_chunk, <<>>)
  }
}

fn create_binary_stream_response(
  stream: yielder.Yielder(BitArray),
) -> Response {
  stream_response(status.ok, stream, "application/octet-stream")
}
