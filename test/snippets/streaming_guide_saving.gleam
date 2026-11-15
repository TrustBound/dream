//// Streaming guide: Saving Streamed Files and Clean Up Resources
////
//// Controllers that write a streamed request body to a file, as shown in
//// docs/guides/streaming.md.

import dream/http/request.{type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String, max_upload_bytes: Int)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) ->
      save_stream_to_file(stream, services.upload_path)
      |> handle_save_result
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

fn save_stream_to_file(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(Nil, simplifile.FileError) {
  use _ <- result.try(simplifile.create_file(path))
  yielder.try_fold(stream, Nil, fn(_nothing, chunk) {
    simplifile.append_bits(path, chunk)
  })
}

fn handle_save_result(result: Result(Nil, simplifile.FileError)) -> Response {
  case result {
    Ok(_) -> text_response(status.ok, "File saved successfully")
    Error(_) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
}

pub type UploadError {
  UploadTooLarge
  WriteFailed(simplifile.FileError)
}

pub fn save_upload_with_limit(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.body {
    Stream(stream) -> save_or_clean_up(stream, services)
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn save_or_clean_up(
  stream: yielder.Yielder(BitArray),
  services: Services,
) -> Response {
  case write_limited_stream(stream, services) {
    Ok(_total_bytes) -> text_response(status.created, "Upload saved")
    Error(error) -> {
      // Clean up the partial upload
      let _ = simplifile.delete(services.upload_path)
      create_failure_response(error)
    }
  }
}

fn write_limited_stream(
  stream: yielder.Yielder(BitArray),
  services: Services,
) -> Result(Int, UploadError) {
  use _ <- result.try(
    simplifile.create_file(services.upload_path)
    |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, 0, fn(total_bytes, chunk) {
    write_chunk(services, total_bytes, chunk)
  })
}

fn write_chunk(
  services: Services,
  total_bytes: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  let new_total = total_bytes + bit_array.byte_size(chunk)
  use _ <- result.try(check_upload_size(new_total, services.max_upload_bytes))
  simplifile.append_bits(services.upload_path, chunk)
  |> result.replace(new_total)
  |> result.map_error(WriteFailed)
}

fn check_upload_size(
  total_bytes: Int,
  max_bytes: Int,
) -> Result(Nil, UploadError) {
  case total_bytes > max_bytes {
    True -> Error(UploadTooLarge)
    False -> Ok(Nil)
  }
}

fn create_failure_response(error: UploadError) -> Response {
  case error {
    UploadTooLarge -> text_response(status.bad_request, "Upload is too large")
    WriteFailed(_reason) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
}
