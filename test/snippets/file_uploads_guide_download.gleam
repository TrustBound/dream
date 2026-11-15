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
