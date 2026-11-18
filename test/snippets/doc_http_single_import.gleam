import dream/http
import gleam/json

pub fn show(request: http.Request, _context, _services) -> http.Response {
  case http.require_int(request, "id") {
    Ok(id) -> http.json_response(http.ok, user_to_json(id))
    Error(_) -> http.json_response(http.bad_request, error_json())
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
