import dream/http/params.{require_int}
import dream/http/request.{type Request}
import dream/http/response.{json_response}
import dream/http/status
import gleam/json

pub fn show(request: Request, _context, _services) {
  case require_int(request, "id") {
    Ok(id) -> json_response(status.ok, user_to_json(id))
    Error(_) -> json_response(status.bad_request, error_json())
  }
}

fn user_to_json(id: Int) -> String {
  json.to_string(json.object([#("id", json.int(id))]))
}

fn error_json() -> String {
  json.to_string(
    json.object([#("error", json.string("id must be an integer"))]),
  )
}
