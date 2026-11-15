# File Uploads

Handle multipart form uploads in Dream.

## Basic Upload <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_upload.gleam#L1-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, created, internal_server_error,
  json_response,
}
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
```

The upload directory comes from your `Services`. Dream has no multipart
parser, so `parse_multipart` and `generate_filename` are small helpers in the
snippet file. Dream gives a buffered route the request body as a `String`, so
these examples only handle files whose content is valid UTF-8.

## Validation

### File Size <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_validation.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

### File Type <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_file_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/list.{contains}

const allowed_types = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "application/pdf",
]

pub fn validate_file_type(content_type: String) -> Result(Nil, String) {
  case contains(allowed_types, content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported file type")
  }
}
```

## Secure Filenames <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_upload.gleam#L117-L154"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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

const safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

/// Random bytes from Erlang's crypto module.
@external(erlang, "crypto", "strong_rand_bytes")
fn random_bytes(count: Int) -> BitArray
```

## Storage Options

### Local Disk <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_multiple.gleam#L40-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn save_to_disk(path: String, content: BitArray) -> Result(String, FileError) {
  simplifile.write_bits(path, content)
  |> result.replace(path)
}
```

### S3 (or Compatible) <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_s3.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_http_client/client.{
  type ClientRequest, type SendError, add_header, body, host, method, path,
  scheme, send,
}
import gleam/http
import gleam/result

pub fn save_to_s3(
  s3_client: ClientRequest,
  filename: String,
  content: String,
) -> Result(String, SendError) {
  // Pass client.new() as s3_client, or a client with a recorder in tests.
  // For clarity, we build the URL parts directly.
  // If you need true binary uploads, consider base64 encoding the payload or
  // using a client that supports binary request bodies.
  let s3_host = "s3.amazonaws.com"
  let s3_path = "/bucket/" <> filename

  s3_client
  |> method(http.Put)
  |> scheme(http.Https)
  |> host(s3_host)
  |> path(s3_path)
  |> add_header("Content-Type", "application/octet-stream")
  |> body(content)
  |> send()
  |> result.map(fn(_body) { filename })
}
```

## Multiple Files <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_multiple.gleam#L1-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, created, internal_server_error,
  json_response,
}
import gleam/json
import gleam/list
import gleam/result
import simplifile.{type FileError}
import snippets/file_uploads_guide_upload.{
  type FileData, type Services, generate_filename, parse_multipart_files,
}

pub fn upload_multiple(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart_files(request) {
    Ok(files) -> save_all_files(files, services.upload_directory)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid files\"}")
  }
}

fn save_all_files(files: List(FileData), directory: String) -> Response {
  let results = list.map(files, save_file_result(_, directory))

  case result.all(results) {
    Ok(filenames) -> json_response(created, filenames_json(filenames))
    Error(_) ->
      json_response(internal_server_error, "{\"error\": \"Some files failed\"}")
  }
}

fn filenames_json(filenames: List(String)) -> String {
  json.object([#("filenames", json.array(filenames, json.string))])
  |> json.to_string()
}
```

## Download Endpoint <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_download.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{type Request, type Response, get_param, ok}
import dream/http/error.{type Error, BadRequest, NotFound}
import dream/http/header.{Header}
import dream/http/response.{Bytes, Response}
import gleam/option.{Some}
import gleam/result
import simplifile
import snippets/controllers_guide_response_helpers as response_helpers
import snippets/file_uploads_guide_upload.{type Services, sanitize_filename}

pub fn download(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    // require_string would drop the extension, so read the raw parameter
    use param <- result.try(
      get_param(request, "filename") |> result.map_error(BadRequest),
    )
    let filename = sanitize_filename(param.raw)
    let path = services.upload_directory <> "/" <> filename
    use content <- result.try(read_upload(path))
    Ok(#(content, filename))
  }

  case result {
    Ok(#(content, filename)) -> file_response(ok, content, filename)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn read_upload(path: String) -> Result(BitArray, Error) {
  simplifile.read_bits(path)
  |> result.replace_error(NotFound("File not found"))
}

fn file_response(
  status_code: Int,
  content: BitArray,
  filename: String,
) -> Response {
  Response(
    status: status_code,
    body: Bytes(content),
    headers: [
      Header("Content-Type", "application/octet-stream"),
      Header(
        "Content-Disposition",
        "attachment; filename=\"" <> filename <> "\"",
      ),
    ],
    cookies: [],
    content_type: Some("application/octet-stream"),
  )
}
```

## Image Resizing <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/file_uploads_guide_image.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

## See Also

- [Streaming](streaming.md) - Stream large files
- [REST API](rest-api.md) - File upload endpoints in APIs
