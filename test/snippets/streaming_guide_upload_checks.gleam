//// Streaming guide: upload checks
////
//// Controllers that check a streamed upload while they read it, as shown in
//// the "Handle Errors Gracefully" and "File Upload with Validation" sections
//// of docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/yielder
import simplifile

const max_upload_bytes = 1_000_000

pub type UploadError {
  UploadTooLarge(limit: Int)
}

pub fn upload_stream(request: Request, _context, _services) -> Response {
  request.stream
  |> option.map(process_stream_safely)
  |> option.map(handle_upload_result)
  |> option.unwrap(text_response(
    status.bad_request,
    "Expected streaming request",
  ))
}

fn process_stream_safely(
  stream: yielder.Yielder(BitArray),
) -> Result(String, UploadError) {
  stream
  |> yielder.try_fold(0, add_chunk_size)
  |> result.map(format_bytes_message)
}

fn add_chunk_size(
  total_bytes: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  let new_total = total_bytes + bit_array.byte_size(chunk)
  case new_total > max_upload_bytes {
    True -> Error(UploadTooLarge(limit: max_upload_bytes))
    False -> Ok(new_total)
  }
}

fn format_bytes_message(total_bytes: Int) -> String {
  "Processed " <> int.to_string(total_bytes) <> " bytes"
}

fn handle_upload_result(result: Result(String, UploadError)) -> Response {
  case result {
    Ok(message) -> text_response(status.ok, message)
    Error(UploadTooLarge(limit)) ->
      text_response(
        status.bad_request,
        "Upload is larger than " <> int.to_string(limit) <> " bytes",
      )
  }
}

pub type ImageError {
  EmptyUpload
  InvalidFileType
  SaveFailed(simplifile.FileError)
}

pub type Services {
  Services(upload_path: String)
}

pub fn upload_image(
  request: Request,
  _context,
  services: Services,
) -> Response {
  request.stream
  |> option.map(validate_and_save_image(_, services.upload_path))
  |> option.map(map_validation_result_to_response)
  |> option.unwrap(text_response(status.bad_request, "Expected file upload"))
}

fn validate_and_save_image(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(String, ImageError) {
  use full_stream <- result.try(validate_image_header(yielder.step(stream)))
  save_to_storage(full_stream, path)
}

fn validate_image_header(
  step: yielder.Step(BitArray, yielder.Yielder(BitArray)),
) -> Result(yielder.Yielder(BitArray), ImageError) {
  case step {
    yielder.Next(first_chunk, rest) -> {
      use _ <- result.try(check_is_valid_image(first_chunk))
      Ok(yielder.prepend(rest, first_chunk))
    }
    yielder.Done -> Error(EmptyUpload)
  }
}

fn check_is_valid_image(chunk: BitArray) -> Result(Nil, ImageError) {
  case is_valid_image(chunk) {
    True -> Ok(Nil)
    False -> Error(InvalidFileType)
  }
}

fn is_valid_image(chunk: BitArray) -> Bool {
  case chunk {
    // PNG
    <<0x89, 0x50, 0x4E, 0x47, _rest:bits>> -> True
    // JPEG
    <<0xFF, 0xD8, 0xFF, _rest:bits>> -> True
    _ -> False
  }
}

fn save_to_storage(
  stream: yielder.Yielder(BitArray),
  path: String,
) -> Result(String, ImageError) {
  use _ <- result.try(
    simplifile.write_bits(path, <<>>) |> result.map_error(SaveFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, chunk) {
    simplifile.append_bits(path, chunk)
  })
  |> result.map_error(SaveFailed)
  |> result.replace(path)
}

fn map_validation_result_to_response(
  result: Result(String, ImageError),
) -> Response {
  case result {
    Ok(path) ->
      json_response(
        status.created,
        json.to_string(json.object([#("path", json.string(path))])),
      )
    Error(InvalidFileType) ->
      text_response(status.unprocessable_content, "Invalid image format")
    Error(_) -> text_response(status.internal_server_error, "Upload failed")
  }
}
