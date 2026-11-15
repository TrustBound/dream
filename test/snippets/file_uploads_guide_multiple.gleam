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

fn save_to_disk(path: String, content: BitArray) -> Result(String, FileError) {
  simplifile.write_bits(path, content)
  |> result.replace(path)
}

fn save_file_result(
  file_data: FileData,
  directory: String,
) -> Result(String, FileError) {
  let filename = generate_filename(file_data.original_name)
  save_to_disk(directory <> "/" <> filename, file_data.content)
  |> result.replace(filename)
}
