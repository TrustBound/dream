# File Uploads

Handle multipart form uploads in Dream.

## Basic Upload

```gleam
import dream/http.{type Request, type Response, json_response, created, bad_request, internal_server_error}
import dream/context.{AppContext}
import gleam/http
import services.{Services}
import simplifile

pub type FileData {
  FileData(
    original_name: String,
    content: BitArray,
    content_type: String,
  )
}

pub fn upload(request: Request, context: AppContext, services: Services) -> Response {
  case parse_multipart(request.body) {
    Ok(file_data) -> save_file(file_data)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn save_file(file_data: FileData) -> Response {
  let filename = generate_filename(file_data.original_name)
  let path = "uploads/" <> filename
  
  case simplifile.write_bits(path, file_data.content) {
    Ok(_) -> json_response(created, success_json(filename))
    Error(_) -> json_response(internal_server_error, "{\"error\": \"Save failed\"}")
  }
}

fn success_json(filename: String) -> String {
  "{\"filename\": \"" <> filename <> "\"}"
}
```

## Validation

### File Size

```gleam
import dream/http.{type Request, type Response, json_response, bad_request, payload_too_large, unsupported_media_type}
import dream/context.{AppContext}
import gleam/bit_array.{byte_size}
import services.{Services}

const max_file_size = 10_000_000  // 10MB

pub fn upload(request: Request, context: AppContext, services: Services) -> Response {
  case parse_multipart(request.body) {
    Ok(file_data) -> validate_and_save(file_data)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_save(file_data: FileData) -> Response {
  case validate_file_size(file_data.content) {
    Error(msg) -> json_response(payload_too_large, error_json(msg))
    Ok(_) -> check_file_type(file_data)
  }
}

fn check_file_type(file_data: FileData) -> Response {
  case validate_file_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> save_file(file_data)
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
  "{\"error\": \"" <> message <> "\"}"
}
```

### File Type

```gleam
import gleam/list.{contains}

const allowed_types = ["image/jpeg", "image/png", "image/gif", "application/pdf"]

fn validate_file_type(content_type: String) -> Result(Nil, String) {
  case contains(allowed_types, content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported file type")
  }
}
```

## Secure Filenames

```gleam
import gleam/string.{split}
import gleam/regexp.{from_string, replace}
import youid

fn generate_filename(original_name: String) -> String {
  let extension = get_extension(original_name)
  let unique_id = youid.v4()
  
  unique_id <> extension
}

fn get_extension(filename: String) -> String {
  case split(filename, ".") {
    [..., ext] -> "." <> ext
    _ -> ""
  }
}

fn sanitize_filename(filename: String) -> String {
  let assert Ok(re) = from_string("[^a-zA-Z0-9._-]")
  replace(re, filename, "_")
}
```

## Storage Options

### Local Disk

```gleam
fn save_to_disk(path: String, content: BitArray) -> Result(String, Error) {
  case simplifile.write_bits(path, content) {
    Ok(_) -> Ok(path)
    Error(_) -> Error(FileSystemError)
  }
}
```

### S3 (or Compatible)

```gleam
import dream_http_client/client.{method, url, header, body_bits, fetch}
import gleam/http.{Put}

fn save_to_s3(
  filename: String,
  content: BitArray,
  http_client: client.Client,
) -> Result(String, FileError) {
  let s3_url = "https://s3.amazonaws.com/bucket/" <> filename
  
  http_client
  |> method(Put)
  |> url(s3_url)
  |> header("Content-Type", "application/octet-stream")
  |> body_bits(content)
  |> fetch()
}
```

## Multiple Files

```gleam
import dream/http.{type Request, type Response, json_response, created, bad_request, internal_server_error}
import dream/context.{AppContext}
import gleam/list.{List, map, all, filter_map}
import gleam/result.{is_ok}
import gleam/string.{join}
import services.{Services}

pub fn upload_multiple(
  request: Request,
  context: AppContext,
  services: Services,
) -> Response {
  case parse_multipart_multiple(request.body) {
    Ok(files) -> save_all_files(files)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid files\"}")
  }
}

fn save_all_files(files: List(FileData)) -> Response {
  let results = map(files, save_file_result)
  
  case all(results, is_ok) {
    True -> create_success_response(results)
    False -> json_response(internal_server_error, "{\"error\": \"Some files failed\"}")
  }
}

fn extract_ok_value(result: Result(String, FileError)) -> Option(String) {
  case result {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn create_success_response(results: List(Result(String, FileError))) -> Response {
  let filenames = filter_map(results, extract_ok_value)
  json_response(created, filenames_json(filenames))
}

fn filenames_json(filenames: List(String)) -> String {
  "{\"filenames\": [" <> join(filenames, ",") <> "]}"
}
```

## Download Endpoint

```gleam
import dream/http.{require_string, type Request, type Response}
import dream/http.{type Request, type Response, text_response, ok, not_found}
import dream/context.{AppContext}
import gleam/option.{Some}
import gleam/result
import services.{Services}
import simplifile
import utilities/response_helpers

pub fn download(request: Request, context: AppContext, services: Services) -> Response {
  let result = {
    use filename <- result.try(require_string(request, "filename"))
    let path = "uploads/" <> sanitize_filename(filename)
    use content <- result.try(simplifile.read_bits(path))
    Ok(#(content, filename))
  }
  
  case result {
    Ok(#(content, filename)) -> file_response(ok, content, filename)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn file_response(status_code: Int, content: BitArray, filename: String) -> Response {
  Response(
    status: status_code,
    body: Bytes(content),
    headers: [
      Header("Content-Type", "application/octet-stream"),
      Header("Content-Disposition", "attachment; filename=\"" <> filename <> "\""),
    ],
    cookies: [],
    content_type: Some("application/octet-stream"),
  )
}
```

## Image Resizing

```gleam
import dream/http.{type Request, type Response, json_response, bad_request, unsupported_media_type, internal_server_error}
import dream/context.{AppContext}
import services.{Services}

// For image processing, use FFI to call ImageMagick or similar
@external(erlang, "image_ffi", "resize")
pub fn resize_image(content: BitArray, width: Int, height: Int) -> Result(BitArray, FileError)

pub fn upload_image(request: Request, context: AppContext, services: Services) -> Response {
  case parse_multipart(request.body) {
    Ok(file_data) -> validate_and_resize(file_data)
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid file\"}")
  }
}

fn validate_and_resize(file_data: FileData) -> Response {
  case validate_image_type(file_data.content_type) {
    Error(msg) -> json_response(unsupported_media_type, error_json(msg))
    Ok(_) -> resize_and_save(file_data)
  }
}

fn resize_and_save(file_data: FileData) -> Response {
  case resize_image(file_data.content, 800, 600) {
    Ok(resized) -> save_file_data(file_data, resized)
    Error(_) -> json_response(internal_server_error, "{\"error\": \"Resize failed\"}")
  }
}

fn save_file_data(file_data: FileData, content: BitArray) -> Response {
  let updated_file = FileData(..file_data, content: content)
  save_file(updated_file)
}
```

## See Also

- [Streaming](streaming.md) - Stream large files
- [REST API](rest-api.md) - File upload endpoints in APIs

