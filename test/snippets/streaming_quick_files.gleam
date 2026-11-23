//// Streaming quick reference: saving and checking uploads
////
//// Controllers that save a streamed upload to a file and check its first
//// chunk, as shown in docs/guides/streaming-quick-reference.md.

import dream/http/request.{type BodyReadError, type Request, Stream}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/result
import gleam/yielder
import simplifile

pub type Services {
  Services(upload_path: String)
}

pub type UploadError {
  EmptyUpload
  InvalidFileType
  // The connection broke before the client sent the whole body
  UploadBroke(BodyReadError)
  SaveFailed(simplifile.FileError)
}

pub fn save_upload(request: Request, _context, services: Services) -> Response {
  case request.body {
    Stream(stream) -> save_stream_to_disk(stream, services.upload_path)
    _ -> text_response(status.bad_request, "Expected file upload")
  }
}

fn save_stream_to_disk(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Response {
  case write_stream_to_file(stream, file_path) {
    Ok(Nil) -> text_response(status.ok, "File saved: " <> file_path)
    Error(UploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
    Error(_reason) -> text_response(status.internal_server_error, "Save failed")
  }
}

// Writes each chunk. On an error, deletes the partial file.
fn write_stream_to_file(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.write_bits(file_path, <<>>) |> result.map_error(SaveFailed),
  )
  yielder.try_fold(stream, Nil, fn(_nothing, item) {
    append_item(file_path, item)
  })
  |> result.try_recover(delete_partial_file(file_path, _))
}

fn append_item(
  file_path: String,
  item: Result(BitArray, BodyReadError),
) -> Result(Nil, UploadError) {
  use chunk <- result.try(result.map_error(item, UploadBroke))
  simplifile.append_bits(file_path, chunk) |> result.map_error(SaveFailed)
}

fn delete_partial_file(
  file_path: String,
  error: UploadError,
) -> Result(Nil, UploadError) {
  use _ <- result.try(
    simplifile.delete(file_path) |> result.map_error(SaveFailed),
  )
  Error(error)
}

pub fn upload_image(
  request: Request,
  _context,
  services: Services,
) -> Response {
  case request.body {
    Stream(stream) ->
      validate_and_save(stream, services.upload_path)
      |> create_image_response
    _ -> text_response(status.bad_request, "Expected image upload")
  }
}

fn validate_and_save(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  // Check the first chunk for magic bytes
  case yielder.step(stream) {
    yielder.Next(Ok(first_chunk), rest) ->
      save_if_image(first_chunk, rest, file_path)
    yielder.Next(Error(read_error), _rest) -> Error(UploadBroke(read_error))
    yielder.Done -> Error(EmptyUpload)
  }
}

fn save_if_image(
  first_chunk: BitArray,
  rest: yielder.Yielder(Result(BitArray, BodyReadError)),
  file_path: String,
) -> Result(Nil, UploadError) {
  case is_valid_image_header(first_chunk) {
    // Put the first chunk back in front of the rest of the stream
    True ->
      yielder.prepend(rest, Ok(first_chunk))
      |> write_stream_to_file(file_path)
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
    Error(UploadBroke(_read_error)) ->
      text_response(status.bad_request, "The upload stopped before its end")
    Error(SaveFailed(_reason)) ->
      text_response(status.internal_server_error, "Upload failed")
  }
}
