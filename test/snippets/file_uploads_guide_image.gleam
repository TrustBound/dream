import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, internal_server_error, json_response,
}
import gleam/json
import gleam/list
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, FileData, parse_multipart, save_file,
}

// Dream has no constant for this status code
const unsupported_media_type = 415

// For image processing, use FFI to call ImageMagick or similar
@external(erlang, "file_uploads_guide_image_ffi", "resize")
pub fn resize_image(
  content: BitArray,
  width: Int,
  height: Int,
) -> Result(BitArray, Nil)

pub fn upload_image(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> validate_and_resize(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_resize(file_data: FileData, directory: String) -> Response {
  case validate_image_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> resize_and_save(file_data, directory)
  }
}

fn resize_and_save(file_data: FileData, directory: String) -> Response {
  case resize_image(file_data.content, 800, 600) {
    Ok(resized) -> save_file_data(file_data, resized, directory)
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Resize failed\"}")
  }
}

fn save_file_data(
  file_data: FileData,
  content: BitArray,
  directory: String,
) -> Response {
  let updated_file = FileData(..file_data, content: content)
  save_file(updated_file, directory)
}

fn validate_image_type(content_type: String) -> Result(Nil, String) {
  case list.contains(["image/jpeg", "image/png", "image/gif"], content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported image type")
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
