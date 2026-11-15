//// Streaming quick reference: saving and checking uploads
////
//// Controllers that save a streamed upload to a file and check its first
//// chunk, as shown in docs/guides/streaming-quick-reference.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/option.{None, Some}
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.stream {
    Some(stream) -> save_stream_to_disk(stream, services.upload_path)
    None -> text_response(status.bad_request, "Expected file upload")
  }
}

fn save_stream_to_disk(
  stream: yielder.Yielder(BitArray),
  file_path: String,
) -> Response {
  case write_stream_to_file(stream, file_path) {
    Ok(Nil) -> text_response(status.ok, "File saved: " <> file_path)
    Error(_reason) -> text_response(status.internal_server_error, "Save failed")
  }
}

fn write_stream_to_file(
  stream: yielder.Yielder(BitArray),
  file_path: String,
) -> Result(Nil, simplifile.FileError) {
  use _ <- result.try(simplifile.write_bits(file_path, <<>>))
  yielder.try_fold(stream, Nil, fn(_nothing, chunk) {
    simplifile.append_bits(file_path, chunk)
  })
}

pub type UploadError {
  EmptyUpload
  InvalidFileType
  SaveFailed(simplifile.FileError)
}

pub fn upload_image(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.stream {
    Some(stream) ->
      validate_and_save(stream, services.upload_path)
      |> create_image_response
    None -> text_response(status.bad_request, "Expected image upload")
  }
}

fn validate_and_save(
  stream: yielder.Yielder(BitArray),
  file_path: String,
) -> Result(Nil, UploadError) {
  // Check the first chunk for magic bytes
  case yielder.step(stream) {
    yielder.Next(first_chunk, rest) ->
      save_if_image(first_chunk, rest, file_path)
    yielder.Done -> Error(EmptyUpload)
  }
}

fn save_if_image(
  first_chunk: BitArray,
  rest: yielder.Yielder(BitArray),
  file_path: String,
) -> Result(Nil, UploadError) {
  case is_valid_image_header(first_chunk) {
    // Put the first chunk back in front of the rest of the stream
    True ->
      yielder.prepend(rest, first_chunk)
      |> write_stream_to_file(file_path)
      |> result.map_error(SaveFailed)
    False -> Error(InvalidFileType)
  }
}

fn is_valid_image_header(chunk: BitArray) -> Bool {
  case chunk {
    // PNG
    <<0x89, 0x50, 0x4E, 0x47, _rest:bits>> -> True
    // JPEG
    <<0xFF, 0xD8, 0xFF, _rest:bits>> -> True
    _ -> False
  }
}

fn create_image_response(result: Result(Nil, UploadError)) -> Response {
  case result {
    Ok(Nil) -> text_response(status.created, "Image saved")
    Error(InvalidFileType) ->
      text_response(status.unprocessable_content, "Not an image")
    Error(EmptyUpload) -> text_response(status.bad_request, "Empty upload")
    Error(SaveFailed(_reason)) ->
      text_response(status.internal_server_error, "Upload failed")
  }
}
