import dream/http/response
import dream/http/status
import simplifile

pub fn serve_image(_request, _context, _services) {
  case simplifile.read_bits("logo.png") {
    Ok(image_data) ->
      response.binary_response(status.ok, image_data, "image/png")
    Error(_) -> response.empty_response(status.not_found)
  }
}
