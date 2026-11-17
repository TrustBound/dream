import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, created, internal_server_error,
  json_response,
}
import dream/http/request.{body_as_string}
import gleam/bit_array
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import simplifile

pub type FileData {
  FileData(original_name: String, content: BitArray, content_type: String)
}

pub fn upload(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart(request) {
    Ok(file_data) -> save_file(file_data, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

pub fn save_file(file_data: FileData, directory: String) -> Response {
  let filename = generate_filename(file_data.original_name)
  let path = directory <> "/" <> filename

  case simplifile.write_bits(path, file_data.content) {
    Ok(_) -> json_response(created, success_json(filename))
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Save failed\"}")
  }
}

fn success_json(filename: String) -> String {
  json.object([#("filename", json.string(filename))])
  |> json.to_string()
}

// ============================================================================
// Helpers for the examples
// ============================================================================

/// The services of the file upload examples.
pub type Services {
  Services(upload_directory: String)
}

/// Read the first file from a multipart/form-data request body.
///
/// Dream has no multipart parser. This minimal one is enough for the guide's
/// examples. It reads the body with `body_as_string`, so it only handles
/// files whose content is valid UTF-8: a binary upload arrives as `Bytes`
/// and gives `Error(Nil)` here.
pub fn parse_multipart(request: Request) -> Result(FileData, Nil) {
  use files <- result.try(parse_multipart_files(request))
  list.first(files)
}

/// Read every file from a multipart/form-data request body.
pub fn parse_multipart_files(request: Request) -> Result(List(FileData), Nil) {
  use content_type <- result.try(option.to_result(request.content_type, Nil))
  use #(_, boundary) <- result.try(string.split_once(content_type, "boundary="))
  use body <- result.try(body_as_string(request))
  let files =
    body
    |> string.split("--" <> boundary)
    |> list.filter_map(parse_part)
  require_files(files)
}

fn require_files(files: List(FileData)) -> Result(List(FileData), Nil) {
  case files {
    [] -> Error(Nil)
    _ -> Ok(files)
  }
}

fn parse_part(part: String) -> Result(FileData, Nil) {
  use #(head, content) <- result.try(string.split_once(part, "\r\n\r\n"))
  use filename <- result.try(quoted_parameter(head, "filename=\""))
  let content_type =
    header_value(head, "Content-Type: ")
    |> result.unwrap("application/octet-stream")
  Ok(FileData(
    original_name: filename,
    content: drop_line_end(content),
    content_type: content_type,
  ))
}

fn quoted_parameter(head: String, prefix: String) -> Result(String, Nil) {
  use #(_, rest) <- result.try(string.split_once(head, prefix))
  use #(value, _) <- result.try(string.split_once(rest, "\""))
  Ok(value)
}

fn header_value(head: String, prefix: String) -> Result(String, Nil) {
  use #(_, rest) <- result.try(string.split_once(head, prefix))
  string.split_once(rest, "\r\n")
  |> result.map(fn(pair) { pair.0 })
  |> result.or(Ok(rest))
}

fn drop_line_end(content: String) -> BitArray {
  let bytes = bit_array.from_string(content)
  let size = bit_array.byte_size(bytes)
  case string.ends_with(content, "\r\n") {
    True -> bit_array.slice(bytes, 0, size - 2) |> result.unwrap(bytes)
    False -> bytes
  }
}

/// Make a random file name that keeps the original extension.
pub fn generate_filename(original_name: String) -> String {
  let unique_id = string.lowercase(bit_array.base16_encode(random_bytes(16)))
  unique_id <> get_extension(original_name)
}

fn get_extension(filename: String) -> String {
  case string.split(filename, ".") {
    [_, _, ..] as parts -> "." <> sanitize_filename(last_part(parts))
    _ -> ""
  }
}

fn last_part(parts: List(String)) -> String {
  list.last(parts) |> result.unwrap("")
}

/// Replace every character that is not a letter, digit, dot, underscore or
/// dash with an underscore.
pub fn sanitize_filename(filename: String) -> String {
  filename
  |> string.to_graphemes()
  |> list.map(replace_unsafe_character)
  |> string.concat()
}

fn replace_unsafe_character(character: String) -> String {
  case string.contains(safe_characters, character) {
    True -> character
    False -> "_"
  }
}

const safe_characters =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

/// Random bytes from Erlang's crypto module.
@external(erlang, "crypto", "strong_rand_bytes")
fn random_bytes(count: Int) -> BitArray
