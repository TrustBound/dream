import dream/context.{type AppContext}
import dream/http.{type Request, type Response, bad_request, json_response}
import gleam/bit_array.{byte_size}
import gleam/json
import snippets/file_uploads_guide_file_type.{validate_file_type}
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, parse_multipart, save_file,
}

// Dream has no constants for these status codes
const payload_too_large = 413

const unsupported_media_type = 415

// 10MB
const max_file_size = 10_000_000

pub fn upload(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> validate_and_save(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_save(file_data: FileData, directory: String) -> Response {
  case validate_file_size(file_data.content) {
    Error(msg) -> json_response(payload_too_large, error_json(msg))
    Ok(_) -> check_file_type(file_data, directory)
  }
}

fn check_file_type(file_data: FileData, directory: String) -> Response {
  case validate_file_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> save_file(file_data, directory)
  }
}

fn validate_file_size(content: BitArray) -> Result(Nil, String) {
  let size = byte_size(content)
  case size > max_file_size {
    True -> Error("File too large (max 10MB)")
    False -> Ok(Nil)
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
