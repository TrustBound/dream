//// Streaming guide: Saving Streamed Files and Clean Up Resources
////
//// Controllers that write a streamed request body to a file, as shown in
//// docs/guides/streaming.md.

import dream/http/request.{type BodyReadError, type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String, max_upload_bytes: Int)
}

pub type UploadError {
  // The connection broke before the client sent the whole body
  UploadBroke(BodyReadError)
  // Only the limited upload below gives this error
  UploadTooLarge
  WriteFailed(simplifile.FileError)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) ->
      save_stream_to_file(stream, services.upload_path)
      |> handle_save_result(services.upload_path)
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}

fn save_stream_to_file(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  path: String,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.create_file(path) |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, item) { append_item(path, item) })
}

fn append_item(
  path: String,
  item: Result(BitArray, BodyReadError),
) -> Result(Nil, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
  simplifile.append_bits(path, chunk) |> result.map_error(WriteFailed)
}

fn handle_save_result(
  result: Result(Nil, UploadError),
  path: String,
) -> Response {
  case result {
    Ok(Nil) -> text_response(status.ok, "File saved successfully")
    Error(error) -> delete_partial_file(path, create_failure_response(error))
  }
}

// Never keep part of an upload: delete the file, then answer
fn delete_partial_file(path: String, response: Response) -> Response {
  case simplifile.delete(path) {
    Ok(Nil) -> response
    Error(_delete_error) ->
      text_response(status.internal_server_error, "Failed to delete the file")
  }
}

fn create_failure_response(error: UploadError) -> Response {
  case error {
    UploadBroke(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
    UploadTooLarge -> text_response(status.bad_request, "Upload is too large")
    WriteFailed(_reason) ->
      text_response(status.internal_server_error, "Failed to save file")
  }
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
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  services: Services,
) -> Response {
  case write_limited_stream(stream, services) {
    Ok(_total_bytes) -> text_response(status.created, "Upload saved")
    Error(error) ->
      delete_partial_file(services.upload_path, create_failure_response(error))
  }
}

fn write_limited_stream(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  services: Services,
) -> Result(Int, UploadError) {
  use _ <- result.try(
    simplifile.create_file(services.upload_path)
    |> result.map_error(WriteFailed),
  )
  yielder.try_fold(stream, 0, fn(total_bytes, item) {
    write_item(services, total_bytes, item)
  })
}

fn write_item(
  services: Services,
  total_bytes: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
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
